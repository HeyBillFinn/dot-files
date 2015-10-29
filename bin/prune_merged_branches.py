#!/usr/bin/python
import subprocess
import os
import re

print(subprocess.Popen(['git', 'checkout', 'master'], stdout=subprocess.PIPE).stdout.read())
proc = subprocess.Popen(['git', 'branch', '--merged'], stdout=subprocess.PIPE)
merged_branches = proc.stdout.read()
branches_to_prune = [b for b in map(str.strip, merged_branches.split('\n'))
                        if b != '' and not re.search('^\*', b)
                        and not 'master' == b]
for branch in branches_to_prune:
    proc = subprocess.Popen(['git', 'branch', '-D', branch], stdout=subprocess.PIPE)
    stdout = proc.stdout.read()
    print stdout
print("Merged branches:\n{}".format(merged_branches))
print("Pruned the following branches:\n{}\n".format(branches_to_prune))

proc = subprocess.Popen(['git', 'branch'], stdout=subprocess.PIPE)
stdout = proc.stdout.read()
print("git branch output:\n{}".format(stdout))
