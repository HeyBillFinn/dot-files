#!/usr/bin/python3
import subprocess
import os
import re

print(
    subprocess.Popen(
        ["git", "checkout", "master"], stdout=subprocess.PIPE).stdout.read())

proc = subprocess.Popen(["git", "branch", "--merged"], stdout=subprocess.PIPE)
merged_branches = proc.stdout.read().decode("utf8")
branches_to_prune = [b for b in map(str.strip, merged_branches.split("\n"))
                        if b != "" and not re.search("^\*", b)
                        and not "master" == b]
for branch in branches_to_prune:
    proc = subprocess.Popen(
        ["git", "branch", "-D", branch], stdout=subprocess.PIPE)
    stdout = proc.stdout.read()
    print(stdout)
print("Merged branches:\n{}".format(merged_branches))
print("Pruned the following branches:\n{}\n".format(branches_to_prune))

proc = subprocess.Popen(["git", "branch"], stdout=subprocess.PIPE)
stdout = proc.stdout.read()
print("git branch output:\n{}".format(stdout))

print("git remote update origin --prune")
print(
    subprocess.Popen(
        ["git", "remote", "update", "origin", "--prune"],
        stdout=subprocess.PIPE).stdout.read())

print("removing tmp branches")
proc = subprocess.Popen(["git", "branch"], stdout=subprocess.PIPE)
tmp_branches = proc.stdout.read().decode("utf8")
tmp_branches_to_prune = [b for b in map(str.strip, tmp_branches.split("\n"))
                        if b != "" and re.search("^tmp-", b)
                        and not "master" == b]
for branch in tmp_branches_to_prune:
    print(
        subprocess.Popen(
            ["git", "branch", "-D", branch],
            stdout=subprocess.PIPE).stdout.read())
    print(
        subprocess.Popen(
            ["git", "push", "origin", ":{}".format(branch)],
            stdout=subprocess.PIPE).stdout.read())
print("Pruned the following tmp branches:\n{}\n".format(tmp_branches_to_prune))
