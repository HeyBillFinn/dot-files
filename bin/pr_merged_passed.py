#!/usr/bin/python3

import re
import itertools
import subprocess
import sys

from collections import defaultdict


pr_number = sys.argv[1]
subprocess.run(
    ["git", "fetch", "origin"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT
)
subprocess.run(
    ["git", "fetch", ".", "origin/master:master"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT
)
# git log master --pretty="format:commit %H%nAuthor: %an <%ae> | Date: %ad | Summary: %B%n"
result = subprocess.run(
    ["git", "log", "master", "--pretty='format:commit %H%nAuthor: %an <%ae> | Date: %ad | Summary: %B%n'", "-n", "10"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT
)
stdout = result.stdout.decode("utf-8")
commits = stdout.split("commit ")
most_recent_merges = dict()
for commit in commits:
    lines = commit.splitlines()
    if len(lines) < 2:
        continue
    commit_summary = lines[1]
    print(commit_summary)
    url_line = next(l for l in lines if "https://git.corp.stripe.com/stripe-internal/android/pull/" in l)
    commit_summary_number = re.sub(r".*?(\d+)\)$", r"\1", commit_summary)
    url_line_number = re.sub(r".*?(\d+)\)$", r"\1", url_line)
    if (url_line_number != commit_summary_number):
        print(f"Encountered mismatched numbers: {url_line_number} and {commit_summary_number}; adding both")
        most_recent_merges[url_line_number] = commit_summary
        most_recent_merges[commit_summary_number] = commit_summary
        continue
    most_recent_merges[commit_summary_number] = commit_summary

print("\n".join(most_recent_merges.values()))
if pr_number in most_recent_merges.keys():
    subprocess.run(["say", "merged"])
    subprocess.run(["osascript", "-e", 'display notification "Merged"'])
    sys.exit(1)

sys.exit(0)
