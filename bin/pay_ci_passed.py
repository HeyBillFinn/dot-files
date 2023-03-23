#!/usr/bin/python3

import re
import itertools
import subprocess
import sys

from collections import defaultdict


def parse_table(ascii_table):
    header = []
    data = []
    for line in ascii_table:
        if "-+-" in line:
            continue
        if not header:
            header = list(filter(lambda x: x != "|", line.split()))
            continue
        splitted_line = list(filter(lambda x: x != "|", line.split()))
        assert len(splitted_line) == len(header)
        datum = {}
        for i in range(len(splitted_line)):
            datum[header[i]] = splitted_line[i]
        data.append(datum)
    return data


ref = sys.argv[1]
result = subprocess.run(
    ["pay", "ci:status", "--ref", ref], stdout=subprocess.PIPE, stderr=subprocess.STDOUT
)
stdout = result.stdout.decode("utf-8")
# if "Two-Factor Authentication Required" in stdout:
#     subprocess.run(["sc-2fa"])
print(stdout)
jobs = parse_table(
    list(itertools.dropwhile(lambda l: "-+-" not in l, stdout.splitlines()))
)

unique_jobs = list(set([j["Job"] for j in jobs]))
job_statuses = defaultdict(list)
for j in jobs:
    if "PASSED" in j["Status"]:
        result = "PASSED"
    elif "FAILED" in j["Status"]:
        result = "FAILED"
    else:
        result = "STARTED"
    job_statuses[j["Job"]].append(result)

any_in_progress = False
for (job, statuses) in job_statuses.items():
    if all([s == "FAILED" for s in statuses]):
        subprocess.run(["say", "failed"])
        subprocess.run(["osascript", "-e", 'display notification "Failed"'])
        sys.exit(1)
    elif any([s == "STARTED" for s in statuses]):
        any_in_progress = True

if any_in_progress:
    sys.exit(0)

# Everything must have passed
subprocess.run(["say", "passed"])
subprocess.run(["osascript", "-e", 'display notification "Passed"'])
sys.exit(1)
