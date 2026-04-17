#!/usr/bin/env python3
"""
Review changed Paparazzi screenshot directories one at a time.

For each directory with changes, opens `git diff-image` to show the visual
diff, then prompts:
  [u]ndo    — git checkout -- <dir>  (revert changes)
  [s]tage   — git add <dir>
  [q]uit    — stop reviewing

Usage:
  ./scripts/review-screenshots.py <snapshot-images-dir>

Example:
  ./scripts/review-screenshots.py standalonepos/modules/views/screenshot-tests/src/test/snapshots/images/
"""

import subprocess
import sys


def get_changed_dirs(base_path):
    """Get unique TestClass/images/ directories that have changed PNGs."""
    result = subprocess.run(
        ["git", "diff", "--name-only", "--", base_path],
        capture_output=True,
        text=True,
    )
    seen = set()
    dirs = []
    for line in result.stdout.strip().splitlines():
        # Extract up to: .../images/<TestClassName>/images/
        # The path pattern is: <base>/images/<TestClass>/images/<file>.png
        parts = line.split("/images/")
        if len(parts) >= 3:
            dir_path = f"{parts[0]}/images/{parts[1]}/images"
        elif len(parts) >= 2:
            dir_path = f"{parts[0]}/images/{parts[1].split('/')[0]}"
        else:
            dir_path = line.rsplit("/", 1)[0]

        if dir_path not in seen:
            seen.add(dir_path)
            dirs.append(dir_path)
    return dirs


def count_files(directory):
    """Count changed files in a directory."""
    result = subprocess.run(
        ["git", "diff", "--name-only", "--", directory],
        capture_output=True,
        text=True,
    )
    return len(result.stdout.strip().splitlines())


def main():
    default_dir = "standalonepos/modules/views/screenshot-tests/src/test/snapshots/images/"
    base_path = sys.argv[1] if len(sys.argv) >= 2 else default_dir
    dirs = get_changed_dirs(base_path)

    if not dirs:
        print("No changed screenshot directories found.")
        return

    print(f"Found {len(dirs)} changed directory(ies).\n")

    undone = 0
    staged = 0
    skipped = 0
    review_all = False

    for i, dir_path in enumerate(dirs, 1):
        n_files = count_files(dir_path)
        print(f"\n[{i}/{len(dirs)}] {dir_path} ({n_files} file(s))")
        print("-" * 60)

        if not review_all:
            # Pre-review prompt: decide whether to open diff-image
            while True:
                try:
                    choice = input("[r]eview / [a]ll / [u]ndo / [s]kip / [q]uit: ").strip().lower()
                except (EOFError, KeyboardInterrupt):
                    print("\nQuitting.")
                    return

                if choice in ("r", "review"):
                    break
                elif choice in ("a", "all"):
                    review_all = True
                    break
                elif choice in ("u", "undo"):
                    subprocess.run(["git", "checkout", "--", dir_path])
                    print(f"  Reverted {dir_path}")
                    undone += 1
                    break
                elif choice in ("s", "skip"):
                    print(f"  Skipped {dir_path}")
                    skipped += 1
                    break
                elif choice in ("q", "quit"):
                    print(f"\nStopped. Staged: {staged}, Reverted: {undone}, "
                          f"Skipped: {skipped}, Remaining: {len(dirs) - i + 1}")
                    return
                else:
                    print("  Invalid choice. Enter r, a, u, s, or q.")

            if choice in ("u", "undo", "s", "skip"):
                continue

        # Show visual diff and then prompt for action
        subprocess.run(["git", "diff-image", dir_path])

        while True:
            try:
                choice = input("\n[u]ndo / [s]tage / [q]uit: ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                print("\nQuitting.")
                return

            if choice in ("u", "undo"):
                subprocess.run(["git", "checkout", "--", dir_path])
                print(f"  Reverted {dir_path}")
                undone += 1
                break
            elif choice in ("s", "stage"):
                subprocess.run(["git", "add", dir_path])
                print(f"  Staged {dir_path}")
                staged += 1
                break
            elif choice in ("q", "quit"):
                print(f"\nStopped. Staged: {staged}, Reverted: {undone}, "
                      f"Skipped: {skipped}, Remaining: {len(dirs) - i + 1}")
                return
            else:
                print("  Invalid choice. Enter u, s, or q.")

    print(f"\nDone! Staged: {staged}, Reverted: {undone}, Skipped: {skipped}")


if __name__ == "__main__":
    main()
