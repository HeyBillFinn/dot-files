#!/usr/bin/env python3
"""
Interactive curses-based tool for reviewing changed Paparazzi screenshot directories.

Shows a list of directories with changed screenshots. Navigate and act:
  [j/k/arrows] navigate
  [Enter/r]    review — open git diff-image for the directory
  [l/Enter]    drill down into directory (grouped by test name)
  [S]          sample — open diff-image for one random file in the directory
  [u]          undo — git checkout -- <dir>
  [s]          stage — git add <dir>
  [g/G]        jump to top/bottom
  [q]          quit (or go back from drill-down)

Usage:
  review-screenshots.py [--branch] [snapshot-images-dir]

Options:
  --branch    Compare HEAD vs master instead of working directory changes
"""

import argparse
import curses
import os
import random
import subprocess
import sys


STATUS_PENDING = "pending"
STATUS_STAGED = "staged"
STATUS_REVERTED = "reverted"


def get_changed_png_lines(base_path=None, branch_mode=False):
    if branch_mode:
        cmd = ["git", "diff", "--name-only", "--diff-filter=M", "master...HEAD", "--", "*.png"]
        if base_path:
            cmd = ["git", "diff", "--name-only", "master...HEAD", "--", base_path]
    else:
        cmd = ["git", "diff", "--name-only", "--diff-filter=M", "--", "*.png"]
        if base_path:
            cmd = ["git", "diff", "--name-only", "--", base_path]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return [l for l in result.stdout.strip().splitlines() if l]


def extract_dir(line):
    parts = line.split("/images/")
    if len(parts) >= 3:
        return f"{parts[0]}/images/{parts[1]}/images"
    elif len(parts) >= 2:
        return f"{parts[0]}/images/{parts[1].split('/')[0]}"
    else:
        return line.rsplit("/", 1)[0]


def get_changed_dirs(base_path=None, branch_mode=False):
    lines = get_changed_png_lines(base_path, branch_mode)
    seen = set()
    dirs = []
    for line in lines:
        dir_path = extract_dir(line)
        if dir_path not in seen:
            seen.add(dir_path)
            dirs.append(dir_path)
    return dirs


def count_files(directory, branch_mode=False):
    if branch_mode:
        cmd = ["git", "diff", "--name-only", "master...HEAD", "--", directory]
    else:
        cmd = ["git", "diff", "--name-only", "--", directory]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return len(result.stdout.strip().splitlines())


def get_files_in_dir(directory, branch_mode=False):
    if branch_mode:
        cmd = ["git", "diff", "--name-only", "master...HEAD", "--", directory]
    else:
        cmd = ["git", "diff", "--name-only", "--", directory]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return [l for l in result.stdout.strip().splitlines() if l]


def draw_list(stdscr, items, cursor, scroll_offset):
    height, width = stdscr.getmaxyx()
    header_lines = 3
    footer_lines = 3
    list_height = height - header_lines - footer_lines

    staged = sum(1 for it in items if it["status"] == STATUS_STAGED)
    reverted = sum(1 for it in items if it["status"] == STATUS_REVERTED)
    pending = sum(1 for it in items if it["status"] == STATUS_PENDING)
    total_files = sum(it["count"] for it in items)

    title = f" Screenshot Review — {len(items)} dir(s), {total_files} file(s): {pending} pending, {staged} staged, {reverted} reverted "
    stdscr.attron(curses.A_BOLD)
    stdscr.addnstr(0, 0, title.center(width), width - 1)
    stdscr.attroff(curses.A_BOLD)

    if not items:
        stdscr.addnstr(3, 2, "No changed screenshot directories found.", width - 4)
        return

    col_headers = f"{'#':>5}  {'STATUS':<10} {'FILES':>5}  DIRECTORY"
    stdscr.attron(curses.A_DIM)
    stdscr.addnstr(1, 0, col_headers.ljust(width - 1), width - 1)
    stdscr.attroff(curses.A_DIM)

    for i in range(list_height):
        idx = scroll_offset + i
        row = header_lines + i
        if idx >= len(items):
            stdscr.move(row, 0)
            stdscr.clrtoeol()
            continue

        it = items[idx]
        status_str = it["status"]
        line = f" {idx + 1:>4}. {status_str:<10} {it['count']:>5}  {it['path']}"

        if idx == cursor:
            stdscr.attron(curses.color_pair(1))
            stdscr.addnstr(row, 0, line.ljust(width - 1), width - 1)
            stdscr.attroff(curses.color_pair(1))
        elif it["status"] == STATUS_STAGED:
            stdscr.attron(curses.color_pair(2))
            stdscr.addnstr(row, 0, line.ljust(width - 1), width - 1)
            stdscr.attroff(curses.color_pair(2))
        elif it["status"] == STATUS_REVERTED:
            stdscr.attron(curses.color_pair(3))
            stdscr.addnstr(row, 0, line.ljust(width - 1), width - 1)
            stdscr.attroff(curses.color_pair(3))
        else:
            stdscr.addnstr(row, 0, line.ljust(width - 1), width - 1)

    help_row = height - 2
    help_text = " [j/k] navigate  [Enter/l] drill down  [r] review  [S] sample  [u] undo  [s] stage  [U] undo all  [g/G] top/bottom  [q] quit"
    stdscr.attron(curses.A_DIM)
    stdscr.addnstr(help_row, 0, help_text.center(width), width - 1)
    stdscr.attroff(curses.A_DIM)


def review_path(stdscr, path, branch_mode=False):
    curses.endwin()
    if branch_mode:
        subprocess.run(["git", "diff-image", "master...HEAD", "--", path])
    else:
        subprocess.run(["git", "diff-image", path])
    stdscr = curses.initscr()
    curses.noecho()
    curses.cbreak()
    stdscr.keypad(True)
    curses.curs_set(0)
    return stdscr


def draw_drilldown(stdscr, dir_path, items, cursor, scroll_offset):
    height, width = stdscr.getmaxyx()
    header_lines = 3
    footer_lines = 3
    list_height = height - header_lines - footer_lines

    staged = sum(1 for it in items if it["status"] == STATUS_STAGED)
    reverted = sum(1 for it in items if it["status"] == STATUS_REVERTED)
    pending = sum(1 for it in items if it["status"] == STATUS_PENDING)

    title = f" {dir_path} — {len(items)} file(s): {pending} pending, {staged} staged, {reverted} reverted "
    stdscr.attron(curses.A_BOLD)
    stdscr.addnstr(0, 0, title[:width - 1].center(width), width - 1)
    stdscr.attroff(curses.A_BOLD)

    col_headers = f"{'#':>5}  {'STATUS':<10} FILE"
    stdscr.attron(curses.A_DIM)
    stdscr.addnstr(1, 0, col_headers.ljust(width - 1), width - 1)
    stdscr.attroff(curses.A_DIM)

    for i in range(list_height):
        idx = scroll_offset + i
        row = header_lines + i
        if idx >= len(items):
            stdscr.move(row, 0)
            stdscr.clrtoeol()
            continue

        it = items[idx]
        filename = os.path.basename(it["path"])
        line = f" {idx + 1:>4}. {it['status']:<10} {filename}"

        if idx == cursor:
            stdscr.attron(curses.color_pair(1))
            stdscr.addnstr(row, 0, line.ljust(width - 1), width - 1)
            stdscr.attroff(curses.color_pair(1))
        elif it["status"] == STATUS_STAGED:
            stdscr.attron(curses.color_pair(2))
            stdscr.addnstr(row, 0, line.ljust(width - 1), width - 1)
            stdscr.attroff(curses.color_pair(2))
        elif it["status"] == STATUS_REVERTED:
            stdscr.attron(curses.color_pair(3))
            stdscr.addnstr(row, 0, line.ljust(width - 1), width - 1)
            stdscr.attroff(curses.color_pair(3))
        else:
            stdscr.addnstr(row, 0, line.ljust(width - 1), width - 1)

    help_row = height - 2
    help_text = " [j/k] navigate  [Enter/r] review  [u] undo  [s] stage  [g/G] top/bottom  [q/h] back"
    stdscr.attron(curses.A_DIM)
    stdscr.addnstr(help_row, 0, help_text.center(width), width - 1)
    stdscr.attroff(curses.A_DIM)


def drilldown_loop(stdscr, dir_path, branch_mode=False):
    """Drill-down view listing individual files within a directory."""
    files = get_files_in_dir(dir_path, branch_mode)
    items = [{"path": f, "status": STATUS_PENDING} for f in sorted(files)]

    cursor = 0
    scroll_offset = 0

    while True:
        height, width = stdscr.getmaxyx()
        header_lines = 3
        footer_lines = 3
        list_height = height - header_lines - footer_lines

        if items:
            cursor = max(0, min(cursor, len(items) - 1))
            if cursor < scroll_offset:
                scroll_offset = cursor
            elif cursor >= scroll_offset + list_height:
                scroll_offset = cursor - list_height + 1

        stdscr.clear()
        draw_drilldown(stdscr, dir_path, items, cursor, scroll_offset)
        stdscr.refresh()

        key = stdscr.getch()

        if key == curses.KEY_UP or key == ord("k"):
            if cursor > 0:
                cursor -= 1

        elif key == curses.KEY_DOWN or key == ord("j"):
            if cursor < len(items) - 1:
                cursor += 1

        elif key in (curses.KEY_PPAGE, 21):
            cursor = max(0, cursor - list_height)

        elif key in (curses.KEY_NPAGE, 4):
            cursor = min(len(items) - 1, cursor + list_height)

        elif key == ord("g"):
            cursor = 0

        elif key == ord("G"):
            cursor = max(0, len(items) - 1)

        elif key in (ord("\n"), ord("r")):
            if items:
                stdscr = review_path(stdscr, items[cursor]["path"], branch_mode)

        elif key == ord("u"):
            if items and items[cursor]["status"] == STATUS_PENDING:
                subprocess.run(["git", "checkout", "--", items[cursor]["path"]], capture_output=True)
                items[cursor]["status"] = STATUS_REVERTED
                if cursor < len(items) - 1:
                    cursor += 1

        elif key == ord("s"):
            if items and items[cursor]["status"] == STATUS_PENDING:
                subprocess.run(["git", "add", items[cursor]["path"]], capture_output=True)
                items[cursor]["status"] = STATUS_STAGED
                if cursor < len(items) - 1:
                    cursor += 1

        elif key in (ord("q"), ord("h"), curses.KEY_LEFT):
            break

    return stdscr


def curses_main(stdscr, base_path, branch_mode=False):
    curses.curs_set(0)
    curses.use_default_colors()
    curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_CYAN)
    curses.init_pair(2, curses.COLOR_GREEN, -1)
    curses.init_pair(3, curses.COLOR_RED, -1)

    dirs = get_changed_dirs(base_path, branch_mode)
    items = [{"path": d, "count": count_files(d, branch_mode), "status": STATUS_PENDING} for d in dirs]

    cursor = 0
    scroll_offset = 0

    while True:
        height, width = stdscr.getmaxyx()
        header_lines = 3
        footer_lines = 3
        list_height = height - header_lines - footer_lines

        if items:
            cursor = max(0, min(cursor, len(items) - 1))
            if cursor < scroll_offset:
                scroll_offset = cursor
            elif cursor >= scroll_offset + list_height:
                scroll_offset = cursor - list_height + 1

        stdscr.clear()
        draw_list(stdscr, items, cursor, scroll_offset)
        stdscr.refresh()

        key = stdscr.getch()

        if key == curses.KEY_UP or key == ord("k"):
            if cursor > 0:
                cursor -= 1

        elif key == curses.KEY_DOWN or key == ord("j"):
            if cursor < len(items) - 1:
                cursor += 1

        elif key in (curses.KEY_PPAGE, 21):
            cursor = max(0, cursor - list_height)

        elif key in (curses.KEY_NPAGE, 4):
            cursor = min(len(items) - 1, cursor + list_height)

        elif key == ord("g"):
            cursor = 0

        elif key == ord("G"):
            cursor = max(0, len(items) - 1)

        elif key in (ord("\n"), ord("l"), curses.KEY_RIGHT):
            if items:
                stdscr = drilldown_loop(stdscr, items[cursor]["path"], branch_mode)

        elif key == ord("r"):
            if items:
                stdscr = review_path(stdscr, items[cursor]["path"], branch_mode)

        elif key == ord("S"):
            if items:
                files = get_files_in_dir(items[cursor]["path"], branch_mode)
                if files:
                    stdscr = review_path(stdscr, random.choice(files), branch_mode)

        elif key == ord("u"):
            if items and items[cursor]["status"] == STATUS_PENDING:
                subprocess.run(
                    ["git", "checkout", "--", items[cursor]["path"]],
                    capture_output=True,
                )
                items[cursor]["status"] = STATUS_REVERTED
                if cursor < len(items) - 1:
                    cursor += 1

        elif key == ord("U"):
            for it in items:
                if it["status"] == STATUS_PENDING:
                    subprocess.run(
                        ["git", "checkout", "--", it["path"]],
                        capture_output=True,
                    )
                    it["status"] = STATUS_REVERTED

        elif key == ord("s"):
            if items and items[cursor]["status"] == STATUS_PENDING:
                subprocess.run(
                    ["git", "add", items[cursor]["path"]],
                    capture_output=True,
                )
                items[cursor]["status"] = STATUS_STAGED
                if cursor < len(items) - 1:
                    cursor += 1

        elif key == ord("q"):
            break


def main():
    parser = argparse.ArgumentParser(description="Review changed Paparazzi screenshots")
    parser.add_argument("--branch", action="store_true",
                        help="Compare HEAD vs master instead of working directory")
    parser.add_argument("base_path", nargs="?", default=None,
                        help="Optional path to scope the diff")
    args = parser.parse_args()
    curses.wrapper(lambda stdscr: curses_main(stdscr, args.base_path, args.branch))


if __name__ == "__main__":
    main()
