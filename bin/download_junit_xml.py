#!/usr/bin/env python3
"""Download JUnit XML artifacts from a CIBot build.

Uses the CIBot presigned URL endpoint to download without AWS credentials.
Downloads are gzipped tars containing XML files; by default extracts only
test failures into a single consolidated XML file.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tarfile
import tempfile
from xml.etree import ElementTree as ET


CIBOT_BASE = "https://cibot.corp.stripe.com"


def log(msg, verbose=False, *, level="info"):
    if level == "debug" and not verbose:
        return
    prefix = {"debug": "[debug]", "info": "[*]", "error": "[!]"}.get(level, "")
    print(f"{prefix} {msg}", file=sys.stderr)


def extract_build_token(input_str):
    match = re.search(r"(bui_[A-Za-z0-9]+)", input_str)
    if not match:
        sys.exit(f"Error: could not extract build token from: {input_str}")
    return match.group(1)


def sc_curl(url, verbose=False):
    log(f"sc-curl {url}", verbose, level="debug")
    result = subprocess.run(["sc-curl", "-s", url], capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"sc-curl failed: {result.stderr}")
    log(f"Response: {result.stdout[:200]}...", verbose, level="debug")
    if not result.stdout.strip():
        return []
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as e:
        sys.exit(f"Failed to parse CIBot response as JSON: {e}\nResponse: {result.stdout[:500]}")


def get_presigned_urls(artifact_id, verbose=False):
    """Get presigned S3 download URLs for an artifact via CIBot."""
    url = f"{CIBOT_BASE}/build_artifact_download/{artifact_id}"
    return sc_curl(url, verbose)


def download_url(url, dest, verbose=False):
    """Download a URL using curl (presigned URLs don't need sc-curl)."""
    log(f"curl -o {dest}", verbose, level="debug")
    result = subprocess.run(
        ["curl", "-s", "-f", "-o", dest, url],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        log(f"Download failed: {result.stderr}", level="error")
        return False
    return True


def extract_failures_from_xml(xml_content, verbose=False):
    """Parse JUnit XML and return testsuites/testcases with failures or errors."""
    failed_suites = []
    try:
        # Strip XML declarations that break parsing when wrapped
        cleaned = re.sub(r'<\?xml[^?]*\?>\s*', '', xml_content)
        wrapped = f"<root>{cleaned}</root>"
        root = ET.fromstring(wrapped)
    except ET.ParseError as e:
        log(f"XML parse error: {e}", verbose, level="debug")
        return []

    for testsuite in root.iter("testsuite"):
        failed_cases = []
        for testcase in testsuite.findall("testcase"):
            if testcase.find("failure") is not None or testcase.find("error") is not None:
                failed_cases.append(testcase)

        if failed_cases:
            suite_copy = ET.Element("testsuite")
            for attr in testsuite.attrib:
                suite_copy.set(attr, testsuite.get(attr))
            suite_copy.set("tests", str(len(failed_cases)))
            suite_copy.set("failures", str(len([c for c in failed_cases if c.find("failure") is not None])))
            suite_copy.set("errors", str(len([c for c in failed_cases if c.find("error") is not None])))
            for tc in failed_cases:
                suite_copy.append(tc)
            failed_suites.append(suite_copy)

    return failed_suites


def main():
    parser = argparse.ArgumentParser(
        description="Download JUnit XML artifacts from a CIBot build.",
        epilog="Example: %(prog)s https://cibot.corp.stripe.com/builds/android-build-miscmodules--bui_UYI4hXvQQ7kIKj",
    )
    parser.add_argument("build", help="CIBot build URL or build token (bui_...)")
    parser.add_argument("-o", "--output", help="Output directory (default: junit-<token>)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose logging")
    parser.add_argument("--no-extract", action="store_true", help="Don't extract tar archives, keep as-is")
    parser.add_argument("--all", action="store_true", help="Extract all XML files, not just failures")
    args = parser.parse_args()

    build_token = extract_build_token(args.build)
    output_dir = args.output or f"junit-{build_token}"
    log(f"Build token: {build_token}")

    # Fetch junit_xml artifacts
    api_url = f"{CIBOT_BASE}/api/builds/{build_token}/artifacts?type=junit_xml"
    log(f"Fetching artifacts list", args.verbose, level="debug")
    artifacts = sc_curl(api_url, args.verbose)

    if not artifacts:
        log("No junit_xml type found, fetching all artifacts...")
        all_artifacts = sc_curl(f"{CIBOT_BASE}/api/builds/{build_token}/artifacts", args.verbose)
        artifacts = [
            a for a in all_artifacts
            if a.get("artifact_type") == "junit_xml" or "junit" in a.get("name", "").lower()
        ]
        if not artifacts and all_artifacts:
            log("Available artifact types:", level="error")
            types = sorted(set(a.get("artifact_type", "unknown") for a in all_artifacts))
            for t in types:
                log(f"  - {t}", level="error")

    if not artifacts:
        sys.exit("No JUnit XML artifacts found for this build.")

    log(f"Found {len(artifacts)} artifact(s)")
    os.makedirs(output_dir, exist_ok=True)

    for artifact in artifacts:
        artifact_id = artifact.get("_id")
        size = artifact.get("file_size_bytes", 0)
        log(f"Artifact: {artifact_id} ({size} bytes)", args.verbose, level="debug")

        presigned_urls = get_presigned_urls(artifact_id, args.verbose)
        if not presigned_urls:
            log(f"No presigned URLs returned for {artifact_id}", level="error")
            continue

        url = presigned_urls[0]

        with tempfile.NamedTemporaryFile(suffix=".tar.gz", delete=False) as tmp:
            tmp_path = tmp.name

        log(f"Downloading {artifact_id}...")
        if not download_url(url, tmp_path, args.verbose):
            os.unlink(tmp_path)
            continue

        if args.no_extract:
            dest = os.path.join(output_dir, f"{artifact_id}.tar.gz")
            os.rename(tmp_path, dest)
            log(f"Saved: {dest}")
            continue

        if args.all:
            try:
                with tarfile.open(tmp_path, "r:gz") as tar:
                    members = [m for m in tar.getmembers() if m.name.endswith(".xml")]
                    log(f"Extracting {len(members)} XML files to {output_dir}")
                    tar.extractall(output_dir, members=members)
            except tarfile.TarError as e:
                log(f"Failed to extract tar: {e}", level="error")
                dest = os.path.join(output_dir, f"{artifact_id}.tar.gz")
                os.rename(tmp_path, dest)
                log(f"Saved raw file as: {dest}")
            else:
                os.unlink(tmp_path)
            continue

        # Default: extract only failures into a single XML file
        all_failed_suites = []
        total_xml = 0
        try:
            with tarfile.open(tmp_path, "r:gz") as tar:
                for member in tar.getmembers():
                    if not member.name.endswith(".xml"):
                        continue
                    total_xml += 1
                    f = tar.extractfile(member)
                    if f is None:
                        continue
                    content = f.read().decode("utf-8", errors="replace")
                    failed = extract_failures_from_xml(content, args.verbose)
                    if failed:
                        log(f"  {member.name}: {len(failed)} failed suite(s)", args.verbose, level="debug")
                    all_failed_suites.extend(failed)
        except tarfile.TarError as e:
            log(f"Failed to read tar: {e}", level="error")
            os.unlink(tmp_path)
            continue

        os.unlink(tmp_path)
        log(f"Scanned {total_xml} XML files, found {len(all_failed_suites)} suite(s) with failures")

        if not all_failed_suites:
            log("No test failures found.")
            continue

        # Write consolidated failures XML
        root = ET.Element("testsuites")
        total_tests = 0
        total_failures = 0
        total_errors = 0
        for suite in all_failed_suites:
            root.append(suite)
            total_tests += int(suite.get("tests", "0"))
            total_failures += int(suite.get("failures", "0"))
            total_errors += int(suite.get("errors", "0"))

        root.set("tests", str(total_tests))
        root.set("failures", str(total_failures))
        root.set("errors", str(total_errors))

        dest = os.path.join(output_dir, "failures.xml")
        tree = ET.ElementTree(root)
        ET.indent(tree, space="  ")
        tree.write(dest, encoding="unicode", xml_declaration=True)

        log(f"Wrote {total_failures} failure(s), {total_errors} error(s) across {len(all_failed_suites)} suite(s) to {dest}")

    log(f"Done. Output: {output_dir}")


if __name__ == "__main__":
    main()
