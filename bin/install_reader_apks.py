#!/usr/bin/env python3
"""
Install release APKs (updater + reader) onto a connected device via adb.

Fetches the latest 10 debug versions for:
  - Updater asset: tmda_5300GW1B701e5PnkiTP000000000000
  - Reader asset:  tmda_5300GW1B701c5Pn68Rg000000000000

Lets the user pick a version, downloads the APKs, and installs them
(updater first, then reader) via adb.

Requirements:
  sc-grpcurl, ~/stripe/mint/zoolander checked out, adb
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile

ZOOLANDER_IMPORT_PATH = os.path.expanduser("~/stripe/mint/zoolander")
FENDER_PROTO = "src/proto/com/stripe/terminal/terminal/pub/api/fender/internal_tools_service.proto"
FENDER_HOST = "fender.corp.stripe.com"
FENDER_SERVICE = "com.stripe.terminal.terminal.pub.api.fender.InternalToolsApi"

DEVICE_CONFIGS = {
    "bbpos": {
        "updater_asset_id": "tmda_5300GW1B701e5PnkiTP000000000000",
        "reader_asset_id": "tmda_5300GW1B701c5Pn68Rg000000000000",
        "updater_package": "com.stripe.updater",
        "reader_package": "com.stripe.reader",
        "apk_suffix": "bbpos-debug.apk",
    },
    "verifone": {
        "updater_asset_id": "tmda_5300UDuSM0017eIpR87000000000000",
        "reader_asset_id": "tmda_5300UDuSM0007eIpzeX000000000000",
        "updater_package": "com.priv.stripe.updater.verifone",
        "reader_package": "com.stripe.reader.verifone",
        "apk_suffix": "verifone-debug.apk",
    },
}


def run_grpcurl(method: str, data: dict, verbose: bool = False) -> dict:
    cmd = [
        "sc-grpcurl",
        "-plaintext",
        "-import-path", ZOOLANDER_IMPORT_PATH,
        "-proto", FENDER_PROTO,
        "-d", json.dumps(data),
        "-unix", FENDER_HOST,
        f"{FENDER_SERVICE}/{method}",
    ]
    if verbose:
        print(f"  [debug] {method} request: {json.dumps(data, indent=2)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if verbose:
        print(f"  [debug] {method} stdout: {result.stdout.strip()}")
        if result.stderr.strip():
            print(f"  [debug] {method} stderr: {result.stderr.strip()}")
    if result.returncode != 0:
        raise RuntimeError(f"sc-grpcurl failed:\n{result.stderr.strip()}")
    return json.loads(result.stdout)


def list_asset_versions(asset_id: str, verbose: bool = False) -> list[dict]:
    """Fetch the latest 50 debug versions for a given asset."""
    debug_versions = []
    page_token = None
    while len(debug_versions) < 50:
        req = {"asset_id": asset_id, "is_debug": "DEBUG_ONLY"}
        if page_token:
            req["pagination"] = {"page_token": page_token}
        response = run_grpcurl("ListAssetVersions", req, verbose=verbose)
        for v in response.get("assetVersions", []):
            debug_versions.append(v)
            if len(debug_versions) >= 50:
                break
        pagination = response.get("pagination", {})
        if not pagination.get("hasMore"):
            break
        page_token = pagination.get("nextPageToken")
        if not page_token:
            break
    return debug_versions


def get_s3_url(version: dict) -> str:
    """Build an s3:// URL from the version's url field."""
    url_info = version.get("url", {})
    bucket = url_info.get("host", "")
    path = url_info.get("path", "")
    return f"s3://{bucket}/{path}"


APK_DIR = os.path.expanduser("~/stripe/apks/release")


def apk_local_path(version: str, package: str, apk_suffix: str = "bbpos-debug.apk") -> str:
    """Return the local path for a cached APK following existing naming convention."""
    return os.path.join(APK_DIR, version, f"{package}-{apk_suffix}")


def ensure_apk(s3_url: str, version: str, package: str, apk_suffix: str = "bbpos-debug.apk", verbose: bool = False) -> str:
    """Download and extract APK if not already cached. Returns path to the APK."""
    local_path = apk_local_path(version, package, apk_suffix)

    if os.path.exists(local_path):
        print(f"  Already cached: {local_path}")
        answer = input("  Use cached version? [Y/n] ").strip().lower()
        if answer not in ("n", "no"):
            return local_path
        print("  Re-downloading...")

    os.makedirs(os.path.dirname(local_path), exist_ok=True)

    # Download tar to a temp file, extract the apk to the final location
    with tempfile.TemporaryDirectory() as tmpdir:
        tar_path = os.path.join(tmpdir, "download.apk.tar")
        print(f"  Downloading {s3_url}...")
        cmd = ["sc-aws", "s3", "cp", s3_url, tar_path]
        if verbose:
            print(f"  [debug] {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(f"S3 download failed:\n{result.stderr.strip()}")
        print(f"  Downloaded ({os.path.getsize(tar_path)} bytes)")

        print(f"  Extracting...")
        extract_dir = os.path.join(tmpdir, "extracted")
        os.makedirs(extract_dir)
        result = subprocess.run(
            ["tar", "xf", tar_path, "-C", extract_dir],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            raise RuntimeError(f"tar extract failed:\n{result.stderr.strip()}")

        # Find the .apk and move it to the cache location
        for root, _, files in os.walk(extract_dir):
            for f in files:
                if f.endswith(".apk"):
                    extracted_apk = os.path.join(root, f)
                    os.rename(extracted_apk, local_path)
                    print(f"  Saved: {local_path}")
                    return local_path
        raise RuntimeError(f"No .apk file found in tar archive")


def adb_install(apk_path: str, verbose: bool = False) -> None:
    """Install an APK via adb."""
    print(f"  Running: adb install -r -d {apk_path}")
    result = subprocess.run(
        ["adb", "install", "-r", "-d", apk_path],
        capture_output=not verbose, text=True,
    )
    if result.returncode != 0:
        stderr = result.stderr if not verbose else ""
        stdout = result.stdout if not verbose else ""
        raise RuntimeError(f"adb install failed:\n{stdout}\n{stderr}")
    print("  Install complete.")


def version_prefix(ver: str) -> str:
    """Return the first 3 nibbles of a version string (e.g. '2.43.0' from '2.43.0.5')."""
    parts = ver.split(".")
    return ".".join(parts[:3]) if len(parts) >= 3 else ver


def merge_versions(updater_versions: list[dict], reader_versions: list[dict]) -> tuple[
    list[tuple[str, dict, dict, int, int]],  # matched: (prefix, updater_v, reader_v, u_count, r_count)
    list[tuple[str, str]],  # unmatched: (prefix, which asset has it)
]:
    """Merge updater and reader versions by prefix. Returns matched pairs and unmatched."""
    # Build prefix -> (best_version, count) for each asset
    def collapse(versions: list[dict]) -> dict[str, tuple[dict, int]]:
        result: dict[str, tuple[dict, int]] = {}
        for v in versions:
            ver = v.get("version", "")
            prefix = version_prefix(ver)
            if prefix not in result:
                result[prefix] = (v, 1)
            else:
                best, count = result[prefix]
                result[prefix] = (best, count + 1)
        return result

    updater_by_prefix = collapse(updater_versions)
    reader_by_prefix = collapse(reader_versions)

    all_prefixes = list(dict.fromkeys(
        list(updater_by_prefix.keys()) + list(reader_by_prefix.keys())
    ))

    matched = []
    unmatched = []
    for prefix in all_prefixes:
        u = updater_by_prefix.get(prefix)
        r = reader_by_prefix.get(prefix)
        if u and r:
            matched.append((prefix, u[0], r[0], u[1], r[1]))
        elif u:
            unmatched.append((prefix, "updater only"))
        else:
            unmatched.append((prefix, "reader only"))

    return matched[:10], unmatched


def select_version(matched: list[tuple[str, dict, dict, int, int]]) -> tuple[dict, dict]:
    """Display matched versions and let the user pick one. Returns (updater, reader)."""
    print(f"\n  Available versions (updater + reader):")
    print(f"  {'#':<4} {'Version':<20} {'Updater builds':<18} {'Reader builds'}")
    print(f"  {'-'*4} {'-'*20} {'-'*18} {'-'*15}")
    for i, (prefix, _u, _r, u_count, r_count) in enumerate(matched, 1):
        print(f"  {i:<4} {prefix:<20} {u_count:<18} {r_count}")
    print()
    while True:
        choice = input(f"  Select version [1-{len(matched)}]: ").strip()
        try:
            idx = int(choice) - 1
            if 0 <= idx < len(matched):
                _, updater_v, reader_v, _, _ = matched[idx]
                return updater_v, reader_v
        except ValueError:
            pass
        print(f"  Invalid choice. Enter a number between 1 and {len(matched)}.")




def check_adb_connection() -> bool:
    """Verify adb can reach a device. Returns True if connected, exits if not."""
    result = subprocess.run(
        ["adb", "get-state"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        msg = result.stderr.strip() or result.stdout.strip()
        print(f"\n  ERROR: adb not connected: {msg}", file=sys.stderr)
        sys.exit(1)
    return True


def get_installed_version(package: str) -> str | None:
    """Get the currently installed version of a package via adb."""
    result = subprocess.run(
        ["adb", "shell", "dumpsys", "package", package],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        return None
    for line in result.stdout.splitlines():
        if "versionName" in line:
            return line.strip().split("=", 1)[-1]
    return None


def find_cached_versions(config: dict) -> list[tuple[str, str, str]]:
    """Scan APK_DIR for cached versions that have both updater and reader APKs.
    Returns list of (version, updater_path, reader_path) sorted newest first."""
    results = []
    if not os.path.isdir(APK_DIR):
        return results
    for version_dir in sorted(os.listdir(APK_DIR), reverse=True):
        updater_path = apk_local_path(version_dir, config["updater_package"], config["apk_suffix"])
        reader_path = apk_local_path(version_dir, config["reader_package"], config["apk_suffix"])
        if os.path.exists(updater_path) and os.path.exists(reader_path):
            results.append((version_dir, updater_path, reader_path))
    return results


def select_cached_version(cached: list[tuple[str, str, str]]) -> tuple[str, str, str]:
    """Display cached versions and let the user pick one."""
    print(f"\n  Cached versions (both updater + reader):")
    print(f"  {'#':<4} {'Version'}")
    print(f"  {'-'*4} {'-'*20}")
    for i, (version, _, _) in enumerate(cached, 1):
        print(f"  {i:<4} {version}")
    print()
    while True:
        choice = input(f"  Select version [1-{len(cached)}]: ").strip()
        try:
            idx = int(choice) - 1
            if 0 <= idx < len(cached):
                return cached[idx]
        except ValueError:
            pass
        print(f"  Invalid choice. Enter a number between 1 and {len(cached)}.")


def main():
    parser = argparse.ArgumentParser(
        description="Install release APKs (updater + reader) onto a connected device via adb."
    )
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="Show debug output for grpcurl and S3 commands")
    args = parser.parse_args()
    verbose = args.verbose

    device_choice = input("\nDevice type — [B]bpos or [v]erifone? [B] ").strip().lower()
    device_type = "verifone" if device_choice in ("v", "verifone") else "bbpos"
    config = DEVICE_CONFIGS[device_type]
    print(f"  Using: {device_type}")

    check_adb_connection()

    print("\nChecking currently installed versions...")
    updater_ver = get_installed_version(config["updater_package"])
    reader_ver = get_installed_version(config["reader_package"])
    print(f"  Updater: {updater_ver or 'not installed'}")
    print(f"  Reader:  {reader_ver or 'not installed'}")

    # Check for locally cached versions first
    cached = find_cached_versions(config)
    if cached:
        print(f"\nLocally cached versions:")
        print(f"  0. Fetch from server")
        for i, (ver, _, _) in enumerate(cached, 1):
            print(f"  {i}. {ver}")
        print()
        while True:
            choice = input(f"  Select version [0-{len(cached)}]: ").strip()
            try:
                idx = int(choice)
                if idx == 0:
                    break
                if 1 <= idx <= len(cached):
                    version, updater_apk, reader_apk = cached[idx - 1]
                    print(f"\n  Ready to install:")
                    print(f"    Updater: {updater_apk}")
                    print(f"    Reader:  {reader_apk}")
                    answer = input("\n  Proceed with install? [y/N] ").strip().lower()
                    if answer != "y":
                        print("  Aborted.")
                        sys.exit(0)
                    print("\n-> Installing updater APK...")
                    adb_install(updater_apk, verbose=verbose)
                    print("\n-> Installing reader APK...")
                    adb_install(reader_apk, verbose=verbose)
                    print("\nDone! Both APKs installed successfully.")
                    return
            except ValueError:
                pass
            print(f"  Invalid choice. Enter a number between 0 and {len(cached)}.")

    print("\nFetching latest debug versions...")

    print("\n  Fetching updater versions...")
    updater_versions = list_asset_versions(config["updater_asset_id"], verbose=verbose)
    if not updater_versions:
        print("  ERROR: No debug versions found for updater asset.", file=sys.stderr)
        sys.exit(1)
    print(f"  Found {len(updater_versions)} debug version(s).")

    print("\n  Fetching reader versions...")
    reader_versions = list_asset_versions(config["reader_asset_id"], verbose=verbose)
    if not reader_versions:
        print("  ERROR: No debug versions found for reader asset.", file=sys.stderr)
        sys.exit(1)
    print(f"  Found {len(reader_versions)} debug version(s).")

    matched, unmatched = merge_versions(updater_versions, reader_versions)

    if unmatched:
        print("\n  Versions without a matching pair (not installable):")
        for prefix, which in unmatched:
            print(f"    {prefix} — {which}")

    if not matched:
        print("\n  ERROR: No versions found with both updater and reader.", file=sys.stderr)
        sys.exit(1)

    updater_choice, reader_choice = select_version(matched)

    print(f"\n  Selected updater: {updater_choice['version']} ({updater_choice['id']})")
    print(f"  Selected reader:  {reader_choice['version']} ({reader_choice['id']})")

    # Build S3 URLs from the version data
    updater_s3 = get_s3_url(updater_choice)
    reader_s3 = get_s3_url(reader_choice)
    version = updater_choice["version"]

    if verbose:
        print(f"  [debug] updater S3: {updater_s3}")
        print(f"  [debug] reader S3:  {reader_s3}")

    # Download/cache APKs
    print("\n-> Preparing updater APK...")
    updater_apk = ensure_apk(updater_s3, version, config["updater_package"], config["apk_suffix"], verbose=verbose)

    print("\n-> Preparing reader APK...")
    reader_apk = ensure_apk(reader_s3, version, config["reader_package"], config["apk_suffix"], verbose=verbose)

    # Confirm install
    print(f"\n  Ready to install:")
    print(f"    Updater: {updater_apk}")
    print(f"    Reader:  {reader_apk}")
    answer = input("\n  Proceed with install? [y/N] ").strip().lower()
    if answer != "y":
        print("  Aborted.")
        sys.exit(0)

    print("\n-> Installing updater APK...")
    adb_install(updater_apk, verbose=verbose)

    print("\n-> Installing reader APK...")
    adb_install(reader_apk, verbose=verbose)

    print("\nDone! Both APKs installed successfully.")


if __name__ == "__main__":
    main()
