#!/usr/bin/python3

import argparse
import re
import itertools
import json
import os
import subprocess
import sys
import threading
import time

from collections import defaultdict, OrderedDict
from datetime import datetime, timedelta
from urllib.parse import quote, urlsplit


IGNORED_JOB_FAILURES = ["android-ios-kmp"]

# Track if we've already triggered a rebuild for android-ios-kmp
android_kmp_rebuild_triggered = False
android_kmp_rebuild_thread = None

# Track if we've already announced "waiting on logs"
waiting_on_logs_announced = False

# Cache the commit -> build-group lookup so normal polling only refreshes the
# build group itself instead of repeating the more expensive wildcard query.
build_group_tokens_cache = {}

# CIBot can take a long time to return an empty result for the wildcard query.
# Bound that lookup so a missing build does not block the watcher indefinitely.
cibot_lookup_timeout = 10

# Merge Queue submission IDs are UUIDs. Keep this deliberately narrower than
# the URL parser below so a commit SHA cannot be mistaken for a submission.
MERGEQ_SUBMISSION_ID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
    re.IGNORECASE,
)
MERGEQ_SUBMISSION_URL_RE = re.compile(
    r"(?:^|/)mergeq/submissions/([^/?#]+)(?:[/?#].*)?$",
    re.IGNORECASE,
)
MERGEQ_SUBMISSION_FAILED_STATUSES = {"ABORTED", "FAILED", "MERGE_FAILED"}
MERGEQ_SUBMISSION_PASSED_STATUSES = {"MERGED"}
MERGEQ_SUBMISSION_ACTIVE_STATUSES = {
    "INIT",
    "QUEUED",
    "QUEUED_OB",
    "IN_BUILD_QUEUE_OB",
    "IN_TREE_OB",
    "TESTING_CHANGE",
    "TESTS_SUCCEEDED",
    "BYPASS",
    "QUEUED_MERGE",
    "REPLICATION_PREPARE",
    "REPLICATION_PROCEED",
}

# Submission builds are created after the submission is queued. Keep the
# tokens we have already seen so a later response cannot make a build vanish
# from the watcher's view.
mergeq_submission_build_tokens_cache = {}
verbose = False

class BuildNotAvailableYet(Exception):
    pass


class TransientNetworkError(Exception):
    pass


class MergeQueueSubmissionFailed(Exception):
    def __init__(self, submission_id, status):
        self.submission_id = submission_id
        self.status = status
        super().__init__(
            f"Merge Queue submission {submission_id} reached terminal status {status}"
        )


class MergeQueueSubmissionPassed(Exception):
    pass


def handle_android_kmp_rebuild(build_id):
    """
    Thread function to handle android-ios-kmp rebuild.
    First runs ./scripts/kmp/ci_send.sh, then triggers a rebuild.
    """
    try:
        print(f"\n[android-ios-kmp] Running ./scripts/kmp/ci_send.sh...")
        result = subprocess.run(
            ["./scripts/kmp/ci_send.sh"],
            capture_output=True,
            text=True,
        )

        if result.returncode != 0:
            print(f"[android-ios-kmp] ci_send.sh failed with return code {result.returncode}")
            print(f"[android-ios-kmp] stderr: {result.stderr}")
            return

        print(f"[android-ios-kmp] ci_send.sh completed successfully")

        # Now trigger the rebuild
        print(f"[android-ios-kmp] Triggering rebuild for build {build_id}...")
        rebuild_result = subprocess.run(
            ["sc-curl", "-X", "POST", f"https://cibot.corp.stripe.com/builds/{build_id}/rebuild"],
            capture_output=True,
            text=True,
        )

        if rebuild_result.returncode != 0:
            print(f"[android-ios-kmp] Rebuild failed with return code {rebuild_result.returncode}")
            print(f"[android-ios-kmp] stderr: {rebuild_result.stderr}")
            return

        print(f"[android-ios-kmp] Rebuild triggered successfully for {build_id}")

    except Exception as e:
        print(f"[android-ios-kmp] Error during rebuild process: {e}")


def get_tmux_window_number():
    tmux_pane = os.environ.get("TMUX_PANE", "")
    # tmux display-message -p -F '#{window_index}' -t "$TMUX_PANE"
    return subprocess.run(
        ["tmux", "display-message", "-p", "-F", "#{window_index}", "-t", tmux_pane],
        capture_output=True,
        text=True,
    ).stdout.strip()


def print_stopped_jobs_and_notify(stopped_jobs):
    print("Stopped jobs:\n")
    print("\n".join(stopped_jobs))
    notify_canceled()


def print_failed_jobs_and_notify(failed_jobs):
    print("Failed jobs:\n")
    print("\n".join(failed_jobs))
    notify_failed()


def notify_canceled():
    subprocess.run(["say", f"job canceled window {get_tmux_window_number()}"])
    subprocess.run(["osascript", "-e", 'display notification "Canceled"'])


def notify_failed():
    subprocess.run(["say", f"failed window {get_tmux_window_number()}"])
    subprocess.run(["osascript", "-e", 'display notification "Failed"'])


def notify_failed_waiting_on_logs():
    subprocess.run(["say", f"job failed waiting on logs window {get_tmux_window_number()}"])
    subprocess.run(["osascript", "-e", 'display notification "Failed - waiting on logs"'])


def notify_failed_logs_ready():
    subprocess.run(["say", f"job failed logs are ready window {get_tmux_window_number()}"])
    subprocess.run(["osascript", "-e", 'display notification "Failed - logs ready"'])


def notify_passed():
    subprocess.run(["say", f"passed window {get_tmux_window_number()}"])
    subprocess.run(["osascript", "-e", 'display notification "Passed"'])


def parse_table(ascii_table):
    header = []
    data = []
    for line in ascii_table:
        if "-+-" in line:
            continue
        # 2025-11-13 Skip errors
        if "Error encountered while resolving destination address" in line:
            continue
        if not header:
            header = list(filter(lambda x: x != "|", line.split()))
            continue
        splitted_line = list(filter(lambda x: x != "|", line.split()))
        if len(splitted_line) != len(header):
            print(f"Header/row mismatch:\n{header}\n{splitted_line}")
            raise BuildNotAvailableYet()
        datum = {}
        for i in range(len(splitted_line)):
            datum[header[i]] = splitted_line[i]
        data.append(datum)
    return data


def strip_ansi(text):
    """Remove ANSI escape codes from a string."""
    if not isinstance(text, str):
        return str(text)
    ansi_escape = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")
    return ansi_escape.sub("", text)


def visible_length(text):
    """Return the visible length of a string, ignoring ANSI escape codes."""
    return len(strip_ansi(text))


def filter_and_print_jobs(jobs):
    # Shorten job names
    for job in jobs:
        job["Job"] = job["Job"].replace("stripe-internal-android-", "android-")
        job["Link"] = job["Link"].replace(
            "https://cibot.corp.stripe.com/builds", "https://go/builds"
        )

    jobs = sorted(jobs, key=lambda j: j["Job"])

    # De-duplicate if same job name and same status
    deduplicated_jobs = OrderedDict()
    for job in jobs:
        key = (job["Job"], job["Status"], job["Link"])
        if key not in deduplicated_jobs:
            deduplicated_jobs[key] = job

    # Convert back to list and ensure all required keys exist
    jobs = list(deduplicated_jobs.values())

    # Annotate failed jobs where logs aren't ready yet
    for job in jobs:
        if "FAILED" in job["Status"] and not job.get("LogsReady", True):
            job["Status"] = job["Status"] + " (logs pending)"

    # # Remove "STOPPED" jobs. This can happen for canceled build groups at the
    # # same git reference.
    # jobs = [j for j in jobs if j["Status"].lower() != "stopped"]

    # Find the maximum visible length for each field
    max_job = max(visible_length(job.get("Job", "")) for job in jobs + [{"Job": "Job"}])
    max_status = max(
        visible_length(job.get("Status", "")) for job in jobs + [{"Status": "Status"}]
    )
    max_duration = max(
        visible_length(job.get("Duration", ""))
        for job in jobs + [{"Duration": "Duration"}]
    )
    max_link = max(
        visible_length(job.get("Link", "")) for job in jobs + [{"Link": "Link"}]
    )

    # Create the format string with dynamic widths
    format_string = "{{:<{}}} {{:<{}}} {{:>{}}} {{:<{}}}".format(
        max_job, max_status, max_duration, max_link
    )

    # Print the header
    print(format_string.format("Job", "Status", "Duration", "Link"))

    # Print each job
    for job in jobs:
        # Pad each field to its maximum width, accounting for ANSI codes
        job_padded = job["Job"].ljust(
            max_job + (len(job["Job"]) - visible_length(job["Job"]))
        )
        status_padded = job["Status"].ljust(
            max_status + (len(job["Status"]) - visible_length(job["Status"]))
        )
        duration_padded = job["Duration"].rjust(
            max_duration + (len(job["Duration"]) - visible_length(job["Duration"]))
        )
        link_padded = job["Link"].ljust(
            max_link + (len(job["Link"]) - visible_length(job["Link"]))
        )

        print(f"{job_padded} {status_padded} {duration_padded} {link_padded}")

    return jobs


def get_git_repo():
    """Return the org/repo path from the current checkout's origin remote."""
    result = subprocess.run(
        ["git", "config", "--get", "remote.origin.url"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    remote = result.stdout.strip()
    if result.returncode != 0 or not remote:
        raise RuntimeError("Could not determine the repository from remote.origin.url")

    if "://" in remote:
        repo = urlsplit(remote).path.strip("/")
    else:
        # SSH remotes use scp syntax: user@host:org/repo.git.
        repo = remote.split(":", 1)[-1].strip("/")
    if repo.endswith(".git"):
        repo = repo[:-4]
    if repo.count("/") < 1:
        raise RuntimeError(f"Could not determine org/repo from origin {remote!r}")
    return repo


def get_build_group_tokens(ref):
    """Find build groups for a commit, independent of user and branch."""
    repo = get_git_repo()
    encoded_ref = quote(ref, safe="")
    try:
        result = subprocess.run(
            [
                "sc-curl",
                "-s",
                "--max-time", str(cibot_lookup_timeout),
                f"cibot.corp.stripe.com/{repo}/commit/{encoded_ref}/builds?branch=%2A",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=cibot_lookup_timeout + 1,
        )
    except subprocess.TimeoutExpired:
        raise BuildNotAvailableYet()
    stdout = result.stdout.decode("utf-8")
    if not stdout.strip():
        raise BuildNotAvailableYet()
    try:
        response = json.loads(stdout)
    except json.JSONDecodeError as error:
        if stdout.strip() == "An unexpected error occurred":
            raise BuildNotAvailableYet()
        print(f"Error reading build information: {error}\n\nstdout:\n{stdout}")
        if "dial tcp: lookup cibot.corp.stripe.com: no such host" in stdout:
            raise TransientNetworkError()
        raise

    builds = response.get("builds", {})
    if not isinstance(builds, dict):
        raise RuntimeError("CIBot returned an unexpected build response")

    # The endpoint returns a map keyed by job name, with a null entry for the
    # aggregate job. Every concrete build carries its parent build-group token.
    return list(dict.fromkeys(
        build["build_group"]
        for build in builds.values()
        if build and build.get("build_group")
    ))


def get_mergeq_submission_id(ref):
    """Return a Merge Queue submission ID when ref is an ID or submission URL."""
    if not isinstance(ref, str):
        return None

    if MERGEQ_SUBMISSION_ID_RE.fullmatch(ref):
        return ref

    match = MERGEQ_SUBMISSION_URL_RE.search(ref)
    if match and MERGEQ_SUBMISSION_ID_RE.fullmatch(match.group(1)):
        return match.group(1)
    return None


def get_mergeq_submission(submission_id):
    """Fetch a Merge Queue submission from CIBot."""
    try:
        result = subprocess.run(
            [
                "sc-curl",
                "-s",
                "--max-time", str(cibot_lookup_timeout),
                f"cibot.corp.stripe.com/api/mergeq/submissions/{quote(submission_id, safe='')}",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=cibot_lookup_timeout + 1,
        )
    except subprocess.TimeoutExpired:
        raise TransientNetworkError()

    stdout = result.stdout.decode("utf-8")
    if not stdout.strip():
        raise TransientNetworkError()
    if "dial tcp: lookup cibot.corp.stripe.com: no such host" in stdout:
        raise TransientNetworkError()

    try:
        response = json.loads(stdout)
    except json.JSONDecodeError as error:
        print(f"Error reading Merge Queue submission: {error}\n\nstdout:\n{stdout}")
        raise

    # The admin endpoint returns the submission itself. Accept the wrapped
    # form too, since other CIBot JSON endpoints return {"submission": ...}.
    submission = response.get("submission", response) if isinstance(response, dict) else None
    if not isinstance(submission, dict):
        raise RuntimeError("CIBot returned an unexpected Merge Queue submission response")
    return submission


def get_git_origin():
    """Return the host portion of the current checkout's origin remote."""
    result = subprocess.run(
        ["git", "config", "--get", "remote.origin.url"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    remote = result.stdout.strip()
    if result.returncode != 0 or not remote:
        raise RuntimeError("Could not determine the repository from remote.origin.url")

    if "://" in remote:
        origin = urlsplit(remote).hostname
    else:
        origin = remote.split("@", 1)[-1].split(":", 1)[0]
    if not origin:
        raise RuntimeError(f"Could not determine the origin host from {remote!r}")
    return origin


def get_current_pr_number():
    """Return the PR number for the current branch, if one is available."""
    try:
        result = subprocess.run(
            ["gh", "pr", "view", "--json", "number", "--jq", ".number"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
    except OSError:
        return None

    if result.returncode != 0:
        return None
    value = result.stdout.strip()
    return int(value) if value.isdigit() else None


def get_mergeq_pr_submissions(origin, owner, repo, pr_number):
    """Fetch all Merge Queue submissions associated with a pull request."""
    try:
        result = subprocess.run(
            [
                "sc-curl",
                "-s",
                "--max-time", str(cibot_lookup_timeout),
                "cibot.corp.stripe.com/api/mergeq/submissions/"
                f"{quote(origin, safe='')}/{quote(owner, safe='')}/"
                f"{quote(repo, safe='')}/pull/{pr_number}",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=cibot_lookup_timeout + 1,
        )
    except subprocess.TimeoutExpired:
        raise TransientNetworkError()

    stdout = result.stdout.decode("utf-8")
    if not stdout.strip():
        raise TransientNetworkError()
    if "dial tcp: lookup cibot.corp.stripe.com: no such host" in stdout:
        raise TransientNetworkError()

    try:
        response = json.loads(stdout)
    except json.JSONDecodeError as error:
        print(f"Error reading Merge Queue PR submissions: {error}\n\nstdout:\n{stdout}")
        raise

    submissions = response.get("submissions", []) if isinstance(response, dict) else response
    if not isinstance(submissions, list):
        raise RuntimeError("CIBot returned an unexpected Merge Queue PR submissions response")
    return [submission for submission in submissions if isinstance(submission, dict)]


def get_active_mergeq_submission_for_current_pr():
    """Return the active Merge Queue submission for the current branch's PR."""
    pr_number = get_current_pr_number()
    if pr_number is None:
        return None

    repo = get_git_repo()
    try:
        owner, repo_name = repo.split("/", 1)
        submissions = get_mergeq_pr_submissions(
            get_git_origin(), owner, repo_name, pr_number
        )
    except (RuntimeError, TransientNetworkError, ValueError) as error:
        if verbose:
            print(f"[verbose] could not look up Merge Queue submission for PR: {error}")
        return None

    for submission in submissions:
        status = str(submission.get("status", "")).upper()
        submission_id = submission.get("id")
        if status in MERGEQ_SUBMISSION_ACTIVE_STATUSES and submission_id:
            return submission_id
    return None


def get_default_ref():
    """Prefer the current PR's active Merge Queue submission, then HEAD."""
    submission_id = get_active_mergeq_submission_for_current_pr()
    if submission_id:
        print(f"Watching active Merge Queue submission {submission_id}")
        return submission_id

    return (
        subprocess.run(
            ["git", "rev-parse", "HEAD"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        .stdout.decode("utf-8")
        .strip()
    )


def get_mergeq_submission_build_tokens(submission):
    """Return all build tokens currently associated with a submission."""
    builds = submission.get("builds", [])
    if not isinstance(builds, list):
        raise RuntimeError("CIBot returned an unexpected Merge Queue builds response")

    tokens = []
    for build in builds:
        if not isinstance(build, dict):
            continue
        token = build.get("build_token") or build.get("buildToken") or build.get("token")
        if token and token not in tokens:
            tokens.append(token)
    return tokens


def handle_mergeq_submission(submission_id):
    """Return jobs for a Merge Queue submission, or wait for its builds."""
    submission = get_mergeq_submission(submission_id)
    status = str(submission.get("status", "STATUS_INVALID")).upper()
    print(f"Merge Queue submission {submission_id}: {status}")

    if status in MERGEQ_SUBMISSION_FAILED_STATUSES:
        raise MergeQueueSubmissionFailed(submission_id, status)
    if status in MERGEQ_SUBMISSION_PASSED_STATUSES:
        raise MergeQueueSubmissionPassed()

    seen_tokens = mergeq_submission_build_tokens_cache.setdefault(submission_id, [])
    for token in get_mergeq_submission_build_tokens(submission):
        if token not in seen_tokens:
            seen_tokens.append(token)

    if not seen_tokens:
        if status == "TESTS_SUCCEEDED":
            raise MergeQueueSubmissionPassed()
        raise BuildNotAvailableYet()

    jobs = []
    for build_token in seen_tokens:
        jobs += handle_build(build_token)
    return jobs


def handle_git_sha(ref):
    build_group_tokens = build_group_tokens_cache.get(ref)
    if build_group_tokens is None:
        build_group_tokens = get_build_group_tokens(ref)
        if len(build_group_tokens) == 0:
            print(f"No build groups matching {ref}")
            raise BuildNotAvailableYet()
        build_group_tokens_cache[ref] = build_group_tokens
        print(f"Found {len(build_group_tokens)} build group(s) for {ref}")

    all_jobs = []
    for build_group_token in build_group_tokens:
        all_jobs += handle_build_group(build_group_token)
    return all_jobs
    # result = subprocess.run(
    #     ["pay", "ci:status", "--ref", ref],
    #     stdout=subprocess.PIPE,
    #     stderr=subprocess.STDOUT,
    # )
    # stdout = result.stdout.decode("utf-8")
    # # if "Two-Factor Authentication Required" in stdout:
    # #     subprocess.run(["sc-2fa"])
    # # print(stdout)
    # jobs = parse_table(
    #     list(itertools.dropwhile(lambda l: "-+-" not in l, stdout.splitlines()))
    # )
    # return jobs


def decorate_status(status):
    BOLD = "\033[1m"
    BRIGHT_GREEN = "\033[92m"
    BRIGHT_RED = "\033[91m"

    RESET = "\033[0m"  # Reset to default
    if status == "PASSED":
        status = f"{BOLD}{BRIGHT_GREEN}{status}{RESET}"
    elif status == "FAILED":
        status = f"{BOLD}{BRIGHT_GREEN}{status}{RESET}"
    return status


def convert_build_to_job(now, raw_build):
    started = raw_build["times"]["started"]
    ended = raw_build["times"]["ended"]
    duration = 0
    if ended is not None:
        duration = ended - started
    elif started is not None:
        duration = round(now - started)

    td = timedelta(seconds=duration)
    return {
        "Job": raw_build["job_name"],
        "Status": decorate_status(raw_build["status"]),
        "Duration": str(td),
        "Link": raw_build["public_url"],
        "BuildID": raw_build.get("token", ""),
        "LogsReady": ended is not None,
    }


def handle_build(ref):
    result = subprocess.run(
        ["sc-curl", "-s", f"cibot.corp.stripe.com/api/builds/{ref}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    stdout = result.stdout.decode("utf-8")
    try:
        raw_build = json.loads(stdout)["build"]
    except json.decoder.JSONDecodeError:
        print("error decoding stdout:")
        print(repr(stdout))
        raise

    if verbose:
        print(f"[verbose] build job_name: {raw_build['job_name']}")

    if raw_build["job_name"] == "stripe-internal-android-selectivity":
        commit_sha = raw_build.get("git_commit_sha")
        if commit_sha:
            try:
                # Find which build group contains this build
                for build_group_token in get_build_group_tokens(commit_sha):
                    bg_builds_result = subprocess.run(
                        [
                            "sc-curl",
                            "-s",
                            f"cibot.corp.stripe.com/api/build_groups/{build_group_token}",
                        ],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT,
                    )
                    bg_builds = json.loads(bg_builds_result.stdout.decode("utf-8"))["builds"]
                    build_tokens = [b["token"] for b in bg_builds]
                    if verbose:
                        print(f"[verbose] bg {build_group_token} has builds: {build_tokens}")
                    if ref in build_tokens:
                        print(
                            f"[selectivity] Build {ref} is a selectivity job, "
                            f"watching build group {build_group_token} instead."
                        )
                        return [convert_build_to_job(time.time(), b) for b in bg_builds]
            except Exception as e:
                if verbose:
                    print(f"[verbose] error finding build group: {e}")

    return [convert_build_to_job(time.time(), raw_build)]


def handle_build_group(ref):
    result = subprocess.run(
        ["sc-curl", "-s", f"cibot.corp.stripe.com/api/build_groups/{ref}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    stdout = result.stdout.decode("utf-8")
    # if "Two-Factor Authentication Required" in stdout:
    #     subprocess.run(["sc-2fa"])
    try:
        raw_builds = json.loads(stdout)["builds"]
    except json.decoder.JSONDecodeError:
        print("error decoding stdout:")
        print(repr(stdout))
        raise
    jobs = []
    now = time.time()
    for raw_build in raw_builds:
        jobs.append(convert_build_to_job(now, raw_build))
    return jobs


def main(ref, force_wait):
    global android_kmp_rebuild_triggered, android_kmp_rebuild_thread, waiting_on_logs_announced

    mergeq_submission_id = get_mergeq_submission_id(ref)
    try:
        if mergeq_submission_id:
            jobs = handle_mergeq_submission(mergeq_submission_id)
        elif ref.startswith("bg_"):
            jobs = handle_build_group(ref)
        elif ref.startswith("bui_"):
            jobs = handle_build(ref)
        else:
            jobs = handle_git_sha(ref)
    except BuildNotAvailableYet:
        print("Build not available yet")
        if mergeq_submission_id:
            return "mergeq_submission_not_ready"
        return "build_not_available"
    except TransientNetworkError:
        print("Transient network error")
        return
    except MergeQueueSubmissionFailed as error:
        print(str(error))
        notify_failed()
        sys.exit(1)
    except MergeQueueSubmissionPassed:
        notify_passed()
        sys.exit(1)

    jobs = filter_and_print_jobs(jobs)
    unique_jobs = list(set([j["Job"] for j in jobs]))
    if len(unique_jobs) == 0:
        print("Failed to find any unique_jobs")
        return

    job_statuses = defaultdict(list)
    job_build_ids = {}
    job_logs_ready = {}
    for j in jobs:
        if "PASSED" in j["Status"]:
            result = "PASSED"
        elif "FAILED" in j["Status"] or "FAILURE" in j["Status"]:
            result = "FAILED"
        elif "STOPPED" in j["Status"]:
            result = "STOPPED"
        else:
            result = "STARTED"
        job_statuses[j["Job"]].append(result)
        # Store build ID for each job (keep the last one if multiple)
        if "BuildID" in j:
            job_build_ids[j["Job"]] = j["BuildID"]
        job_logs_ready[j["Job"]] = j.get("LogsReady", True)

    # Check for android-ios-kmp failure and trigger rebuild if needed
    if "android-ios-kmp" in job_statuses:
        kmp_statuses = job_statuses["android-ios-kmp"]
        if all([s == "FAILED" for s in kmp_statuses]) and not android_kmp_rebuild_triggered:
            android_kmp_rebuild_triggered = True
            build_id = job_build_ids.get("android-ios-kmp", "")
            if build_id:
                print(f"\n[android-ios-kmp] Job failed, triggering rebuild process in background...")
                android_kmp_rebuild_thread = threading.Thread(
                    target=handle_android_kmp_rebuild,
                    args=(build_id,),
                    daemon=False
                )
                android_kmp_rebuild_thread.start()
            else:
                print("[android-ios-kmp] Job failed but no build ID found")

    # Check if rebuild thread is still running
    if android_kmp_rebuild_thread and android_kmp_rebuild_thread.is_alive():
        print("[android-ios-kmp] Rebuild process still running, continuing to monitor...")
        return

    any_in_progress = False
    failed_jobs = []
    stopped_jobs = []
    for job, statuses in job_statuses.items():
        if any(s == "PASSED" for s in statuses):
            continue
        elif job not in IGNORED_JOB_FAILURES and all([s == "FAILED" for s in statuses]):
            failed_jobs.append(job)
        elif all([s == "STOPPED" for s in statuses]):
            stopped_jobs.append(job)
        elif any([s == "STARTED" for s in statuses]):
            any_in_progress = True

    if len(failed_jobs) > 0 and not (force_wait and any_in_progress):
        all_logs_ready = all(job_logs_ready.get(job, True) for job in failed_jobs)

        if not all_logs_ready:
            if not waiting_on_logs_announced:
                waiting_on_logs_announced = True
                print("Failed jobs (logs not yet available):")
                print("\n".join(failed_jobs))
                notify_failed_waiting_on_logs()
            else:
                print("Still waiting on logs...")
            return "waiting_on_logs"

        # Logs are ready
        if waiting_on_logs_announced:
            print_failed_jobs_and_notify(failed_jobs)
            notify_failed_logs_ready()
        else:
            print_failed_jobs_and_notify(failed_jobs)
        sys.exit(1)

    if any_in_progress:
        print("jobs still in progress")
        return None

    if len(stopped_jobs) > 0:
        print_stopped_jobs_and_notify(stopped_jobs)
        sys.exit(1)
    else:
        notify_passed()
        sys.exit(1)


def run():
    # TODO: Support forcibly waiting if we know one job failed but we want to
    # see the results of the other jobs.
    global verbose, cibot_lookup_timeout

    parser = argparse.ArgumentParser(
        description=(
            "Watch CI for a passing build. With no ref, prefer the active "
            "Merge Queue submission for the current PR, then fall back to HEAD."
        )
    )
    parser.add_argument(
        "ref",
        type=str,
        nargs="?",
        help="Git commit hash, build token/group, or Merge Queue submission ID/URL to watch",
    )
    parser.add_argument(
        "--force_wait", action="store_true", help="If true, forcibly waits."
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="Enable verbose debug logging."
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=30,
        metavar="SECONDS",
        help="Seconds between normal status polls (default: 30).",
    )
    parser.add_argument(
        "--lookup-timeout",
        type=int,
        default=10,
        metavar="SECONDS",
        help="Maximum seconds to wait for CIBot lookups (default: 10).",
    )
    args = parser.parse_args()

    force_wait = args.force_wait
    verbose = args.verbose
    poll_interval = max(args.interval, 1)
    cibot_lookup_timeout = max(args.lookup_timeout, 1)

    if args.ref is None:
        ref = get_default_ref()
    else:
        ref = args.ref

    while True:
        print(f"{datetime.now()} running ...")
        result = main(ref, force_wait)
        if result == "mergeq_submission_not_ready":
            seconds = 30
        elif result == "build_not_available":
            seconds = 5
        elif result == "waiting_on_logs":
            seconds = 10
        else:
            seconds = poll_interval
        while seconds > 0:
            mins, secs = divmod(seconds, 60)
            timer = f"{mins:02d}:{secs:02d}"
            sys.stdout.write(f"\r{timer}")  # \r moves cursor to beginning of line
            sys.stdout.flush()  # Ensures immediate display
            time.sleep(1)
            seconds -= 1
        sys.stdout.write("\n")
        sys.stdout.flush()


if __name__ == "__main__":
    run()
