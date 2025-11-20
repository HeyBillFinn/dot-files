#!/usr/bin/python3
import subprocess
import os
import re


def run_command(command):
    try:
        print(command)
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}")
        return None


def delete_branch(branch):
    try:
        run_command(["git", "branch", "-D", branch])
        print(f"Deleted branch: {branch}")
    except subprocess.CalledProcessError as e:
        print(f"Failed to delete branch {branch}: {e}")


def get_branches():
    branches = run_command(["git", "branch"]).split("\n")
    return [
        branch.strip()
        for branch in branches
        if not branch.startswith("*")
        and not re.search("^\*", branch)
        and branch != "master"
    ]


def confirm_and_delete_branch(branch):
    while True:
        print(f"git diff --color master...{branch}")
        diff = run_command(["git", "diff", "--color", f"master...{branch}"])
        print(diff)
        response = input(f"Delete branch '{branch}'? [y/n]: ").lower()
        if response in ["", "y", "yes"]:
            delete_branch(branch)
            return True
        elif response in ["n", "no"]:
            print(f"Skipping branch: {branch}")
            return False
        else:
            print("Invalid input. Please enter 'y' or 'n'.")


# https://stackoverflow.com/a/34337939
def is_branch_merged(branch):
    # Store the current branch
    current_branch = run_command(["git", "rev-parse", "--abbrev-ref", "HEAD"])
    if current_branch is None:
        print("current branch is None")
        return False

    # Checkout master~0
    if run_command(["git", "checkout", "master~0"]) is None:
        print("current branch is None")
        return False

    try:
        # Attempt to merge the branch
        result = subprocess.run(
            ["git", "merge", "--no-commit", "--no-ff", branch],
            capture_output=True,
            text=True,
        )

        # Check if there are any differences
        diff_result = run_command(["git", "diff", "--cached"])

        # Abort the merge
        run_command(["git", "merge", "--abort"])

        # If there's no difference, the branch is considered merged
        return diff_result == ""

    except subprocess.CalledProcessError as e:
        print(f"Error during merge check: {e}")
        return False
    finally:
        # Always return to the original branch
        run_command(["git", "checkout", current_branch])


print(run_command(["git", "checkout", "master"]))

# Merged branches with ~normal rebase history
merged_branches = run_command(["git", "branch", "--merged"])
branches_to_prune = [
    b
    for b in map(str.strip, merged_branches.split("\n"))
    if b != "" and not re.search("^\*", b) and not "master" == b
]
deleted_branches = []
for branch in branches_to_prune:
    delete_branch(branch)
    deleted_branches.append(branch)

# Iterating over all local branches
branches = get_branches()
for branch in branches:
    print(f"Checking branch {branch}")
    if "master" == branch:
        continue
    if not "billfinn" in branch:
        print("not billfinn branch")
        if confirm_and_delete_branch(branch):
            deleted_branches.append(branch)
    elif re.search("^tmp-", branch):
        print("tmp branch; deleting")
        delete_branch(branch)
        deleted_branches.append(branch)
    elif is_branch_merged(branch):
        # Merged branches with abnormal rebase history
        if confirm_and_delete_branch(branch):
            deleted_branches.append(branch)


print("Merged branches:\n{}".format(merged_branches))
print("Deleted the following branches:\n{}\n".format(deleted_branches))

# Prune from origin
print("Pruning origin branches")
print(run_command(["git", "remote", "update", "origin", "--prune"]))
