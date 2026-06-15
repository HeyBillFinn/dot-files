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


IGNORED_JOB_FAILURES = ["android-ios-kmp"]

# Track if we've already triggered a rebuild for android-ios-kmp
android_kmp_rebuild_triggered = False
android_kmp_rebuild_thread = None

# Track if we've already announced "waiting on logs"
waiting_on_logs_announced = False

class BuildNotAvailableYet(Exception):
    pass


class TransientNetworkError(Exception):
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


def handle_git_sha(ref):
    result = subprocess.run(
        ["sc-curl", "-s", f"cibot.corp.stripe.com/user/build_groups?stripe_user=billfinn&limit=50"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    stdout = result.stdout.decode("utf-8")
    try:
        build_groups = json.loads(stdout)["build_groups"]
    except Exception as e:
        print(f"Error reading from json: {e}\n\nstdout:\n{stdout}")
        if "dial tcp: lookup cibot.corp.stripe.com: no such host" in stdout:
            raise TransientNetworkError()
        raise e
    build_groups = [bg for bg in build_groups if bg["commit_id"] == ref]
    if len(build_groups) == 0:
        print(f"No build groups matching ${ref}")
        raise BuildNotAvailableYet()

    # Infer the branch by the oldest timestamp
    oldest_build_group = min(build_groups, key=lambda bg: bg["build_submitted_at"])
    branch = oldest_build_group["branch"]
    print(f"Detected branch {branch}")
    build_groups = [bg for bg in build_groups if bg["branch"] == branch]
    all_jobs = []
    for build_group in build_groups:
        all_jobs += handle_build_group(build_group["token"])
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
            bg_result = subprocess.run(
                ["sc-curl", "-s", f"cibot.corp.stripe.com/user/build_groups?stripe_user=billfinn&limit=50"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
            )
            bg_stdout = bg_result.stdout.decode("utf-8")
            try:
                all_bgs = json.loads(bg_stdout)["build_groups"]
                matching_bgs = [bg for bg in all_bgs if bg["commit_id"] == commit_sha]
                # Find which build group contains this build
                for bg in matching_bgs:
                    bg_builds_result = subprocess.run(
                        ["sc-curl", "-s", f"cibot.corp.stripe.com/api/build_groups/{bg['token']}"],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT,
                    )
                    bg_builds = json.loads(bg_builds_result.stdout.decode("utf-8"))["builds"]
                    build_tokens = [b["token"] for b in bg_builds]
                    if verbose:
                        print(f"[verbose] bg {bg['token']} has builds: {build_tokens}")
                    if ref in build_tokens:
                        print(f"[selectivity] Build {ref} is a selectivity job, watching build group {bg['token']} instead.")
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

    try:
        if ref.startswith("bg_"):
            jobs = handle_build_group(ref)
        elif ref.startswith("bui_"):
            jobs = handle_build(ref)
        else:
            jobs = handle_git_sha(ref)
    except BuildNotAvailableYet:
        print("Build not available yet")
        return
    except TransientNetworkError:
        print("Transient network error")
        return

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
        if job not in IGNORED_JOB_FAILURES and all([s == "FAILED" for s in statuses]):
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


# TODO: Support forcibly waiting if we know one job failed but we want to see
# the results of the other jobs.
parser = argparse.ArgumentParser(description="Watch CI for a passing build.")
parser.add_argument("ref", type=str, nargs="?", help="Git commit hash to watch")
# Optional positional argument
parser.add_argument(
    "--force_wait", action="store_true", help="If true, forcibly waits."
)
parser.add_argument(
    "--verbose", "-v", action="store_true", help="Enable verbose debug logging."
)
args = parser.parse_args()
if args.ref is None:
    ref = (
        subprocess.run(
            ["git", "rev-parse", "HEAD"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        .stdout.decode("utf-8")
        .strip()
    )
else:
    ref = args.ref

force_wait = args.force_wait
verbose = args.verbose

while True:
    print(f"{datetime.now()} running ...")
    result = main(ref, force_wait)
    seconds = 10 if result == "waiting_on_logs" else 30
    while seconds > 0:
        mins, secs = divmod(seconds, 60)
        timer = f"{mins:02d}:{secs:02d}"
        sys.stdout.write(f"\r{timer}")  # \r moves cursor to beginning of line
        sys.stdout.flush()  # Ensures immediate display
        time.sleep(1)
        seconds -= 1
