#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# use: python3 Scripts/biggest_girectory_fixed_level1.py / -n 12

import argparse
import heapq
import os
import sys
from typing import List, Tuple


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Find directories containing the largest number of first-level files and subdirectories."
    )
    parser.add_argument(
        "start",
        nargs="?",
        default=os.path.expanduser("~"),
        help="Start directory. Default: your home directory.",
    )
    parser.add_argument(
        "-n",
        "--top",
        type=int,
        default=12,
        help="How many directories to print. Default: 12.",
    )
    return parser


def count_first_level_entries(path: str) -> int:
    try:
        with os.scandir(path) as entries:
            return sum(1 for _ in entries)
    except (PermissionError, FileNotFoundError, NotADirectoryError, OSError):
        return -1


def find_biggest_directories(start: str, top_n: int) -> List[Tuple[int, str]]:
    heap: List[Tuple[int, str]] = []

    for root, _dirs, _files in os.walk(start, topdown=True, onerror=lambda _e: None):
        count = count_first_level_entries(root)
        if count < 0:
            continue

        item = (count, root)
        if len(heap) < top_n:
            heapq.heappush(heap, item)
        else:
            heapq.heappushpop(heap, item)

    return sorted(heap, reverse=True)


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    start = os.path.abspath(os.path.expanduser(args.start))
    top_n = args.top

    if top_n <= 0:
        print("Error: --top must be greater than 0.", file=sys.stderr)
        return 1

    if not os.path.isdir(start):
        print(f"Error: '{start}' is not a directory.", file=sys.stderr)
        return 1

    for count, path in find_biggest_directories(start, top_n):
        print(f"{count:12d}  {path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
