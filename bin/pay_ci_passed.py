#!/usr/bin/python3

import argparse
import re
import itertools
import json
import os
import subprocess
import sys
import time

from collections import defaultdict, OrderedDict
from datetime import datetime, timedelta


IGNORED_JOB_FAILURES = ["android-ios-kmp"]

class BuildNotAvailableYet(Exception):
    pass


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
        ["pay", "ci:status", "--ref", ref],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    stdout = result.stdout.decode("utf-8")
    # if "Two-Factor Authentication Required" in stdout:
    #     subprocess.run(["sc-2fa"])
    # print(stdout)
    jobs = parse_table(
        list(itertools.dropwhile(lambda l: "-+-" not in l, stdout.splitlines()))
    )
    return jobs


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
    }


def handle_build(ref):
    result = subprocess.run(
        ["sc-curl", "-s", f"cibot.corp.stripe.com/api/builds/{ref}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    stdout = result.stdout.decode("utf-8")
    # if "Two-Factor Authentication Required" in stdout:
    #     subprocess.run(["sc-2fa"])
    raw_build = json.loads(stdout)["build"]
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
    raw_builds = json.loads(stdout)["builds"]
    jobs = []
    now = time.time()
    for raw_build in raw_builds:
        jobs.append(convert_build_to_job(now, raw_build))
    return jobs


def main(ref, force_wait):
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

    jobs = filter_and_print_jobs(jobs)
    unique_jobs = list(set([j["Job"] for j in jobs]))
    if len(unique_jobs) == 0:
        print("Failed to find any unique_jobs")
        return

    job_statuses = defaultdict(list)
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

    if len(failed_jobs) > 0 and not force_wait:
        print_failed_jobs_and_notify(failed_jobs)
        sys.exit(1)

    if any_in_progress:
        print("jobs still in progress")
        return

    if len(failed_jobs) > 0:
        print_failed_jobs_and_notify(failed_jobs)
        sys.exit(1)
    elif len(stopped_jobs) > 0:
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

while True:
    print(f"{datetime.now()} running ...")
    main(ref, force_wait)
    seconds = 30
    while seconds > 0:
        mins, secs = divmod(seconds, 60)
        timer = f"{mins:02d}:{secs:02d}"
        sys.stdout.write(f"\r{timer}")  # \r moves cursor to beginning of line
        sys.stdout.flush()  # Ensures immediate display
        time.sleep(1)
        seconds -= 1
