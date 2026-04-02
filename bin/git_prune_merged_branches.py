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
        print(f"git log --oneline master..{branch}")
        subprocess.run(["git", "log", "--oneline", f"master..{branch}"])
        response = input(f"Delete branch '{branch}'? [y/n]: ").lower()
        if response in ["", "y", "yes"]:
            delete_branch(branch)
            return True
        elif response in ["n", "no"]:
            print(f"Skipping branch: {branch}")
            return False
        else:
            print("Invalid input. Please enter 'y' or 'n'.")


def is_branch_squash_merged(branch, base="master"):
    """Detect if branch was squash-merged into base.

    Works by creating a temporary commit with the branch's tree on top of the
    merge base, then using git cherry to check if that patch is already applied
    upstream. A '-' prefix from git cherry means it's already in base.
    """
    merge_base = run_command(["git", "merge-base", base, branch])
    if not merge_base:
        return False

    tree = run_command(["git", "rev-parse", f"{branch}^{{tree}}"])
    if not tree:
        return False

    temp_commit = run_command(
        ["git", "commit-tree", tree, "-p", merge_base, "-m", "temp squash check"]
    )
    if not temp_commit:
        return False

    result = subprocess.run(
        ["git", "cherry", base, temp_commit], capture_output=True, text=True
    )
    return result.stdout.strip().startswith("-")


def is_branch_merged(branch, base="master"):
    # Fast path: regular merge/rebase (commit is reachable from base)
    merged = run_command(["git", "branch", "--merged", base])
    if merged and branch in merged.split():
        return True

    # Slow path: squash merge (same diff, different commit)
    return is_branch_squash_merged(branch, base)


print(run_command(["git", "checkout", "master"]))

deleted_branches = []
# Remove tmp branches
for branch in [b for b in get_branches() if b.startswith("tmp-") and "billfinn" in b]:
    delete_branch(branch)
    deleted_branches.append(branch)

# Iterating over billfinn branches (non-tmp)
for branch in [b for b in get_branches() if "billfinn" in b and not b.startswith("tmp-")]:
    print(f"Checking branch {branch}")
    if is_branch_merged(branch):
        print(f"Branch appears merged (including squash): {branch}")
        if confirm_and_delete_branch(branch):
            deleted_branches.append(branch)
    else:
        print(f"Branch not merged, skipping: {branch}")
print("Deleted the following branches:\n{}\n".format(deleted_branches))

# Prune from origin
print("Pruning origin branches")
print(run_command(["git", "remote", "update", "origin", "--prune"]))
