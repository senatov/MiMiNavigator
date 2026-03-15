#!/usr/bin/env python3
"""
Fast directory size calculator for MiMiNavigator
Handles symlinks, cloud directories (OneDrive, iCloud), and macOS special folders
Outputs JSON results to /tmp for Swift to read
"""

import os
import sys
import json
import time
from pathlib import Path


# macOS directories that often behave badly with os.walk
SPECIAL_DIRS = {
    "Music",
    "Pictures",
    "Movies",
    "Desktop",
    "Documents",
    "Library"
}


def calculate_size_finder(path):
    """
    Finder / du style disk usage using st_blocks.
    Much faster on large directory trees.
    """
    total = 0
    files = 0
    stack = [path]

    while stack:
        current = stack.pop()

        try:
            with os.scandir(current) as it:
                for entry in it:
                    try:
                        stat = entry.stat(follow_symlinks=False)

                        if entry.is_symlink():
                            continue

                        if entry.is_dir(follow_symlinks=False):
                            stack.append(entry.path)
                        else:
                            # st_blocks are 512 byte blocks
                            total += stat.st_blocks * 512
                            files += 1

                    except (OSError, PermissionError):
                        continue

        except (OSError, PermissionError):
            continue

    return {"size": total, "files": files, "error": None}


def calculate_size_scandir(path):
    """
    Fast recursive size using os.scandir
    Works well for packages, cloud directories and symlinks
    """
    total = 0
    files = 0
    stack = [path]

    while stack:
        current = stack.pop()

        try:
            with os.scandir(current) as it:
                for entry in it:
                    try:
                        if entry.is_symlink():
                            continue

                        if entry.is_file(follow_symlinks=False):
                            stat = entry.stat(follow_symlinks=False)
                            total += stat.st_size
                            files += 1

                        elif entry.is_dir(follow_symlinks=False):
                            stack.append(entry.path)

                    except (OSError, PermissionError):
                        continue

        except (OSError, PermissionError):
            continue

    return {"size": total, "files": files, "error": None}


def calculate_size_walk(path):
    """
    Classic os.walk fallback
    """
    total = 0
    files = 0

    try:
        for root, dirs, filenames in os.walk(path, followlinks=True):
            for name in filenames:
                file_path = os.path.join(root, name)

                try:
                    stat = os.stat(file_path, follow_symlinks=False)
                    total += stat.st_size
                    files += 1
                except (OSError, PermissionError):
                    continue

    except (OSError, PermissionError) as e:
        return {"size": 0, "files": 0, "error": str(e)}

    return {"size": total, "files": files, "error": None}


def calculate_directory_size(path, shallow=False):
    """
    Calculate directory size with optional shallow mode
    """

    try:

        # shallow mode (instant)
        if shallow:
            total = 0
            files = 0

            try:
                with os.scandir(path) as it:
                    for entry in it:
                        try:
                            if entry.is_file(follow_symlinks=False):
                                stat = entry.stat(follow_symlinks=False)
                                total += stat.st_size
                                files += 1
                        except (OSError, PermissionError):
                            continue

            except (OSError, PermissionError) as e:
                return {"size": 0, "files": 0, "error": str(e)}

            return {"size": total, "files": files, "error": None}

        name = os.path.basename(path)

        # Finder-style algorithm for problematic macOS folders
        if name in SPECIAL_DIRS:

            result = calculate_size_finder(path)

            # fallback if macOS privacy blocked access
            if result["size"] == 0 and result["files"] == 0:
                result = calculate_size_scandir(path)

            return result

        # default algorithm
        return calculate_size_walk(path)

    except Exception as e:
        return {"size": 0, "files": 0, "error": str(e)}


def main():

    if len(sys.argv) != 4:
        print("Usage: directory_size.py <path> <shallow|full> <output_file>", file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]
    mode = sys.argv[2]
    output_file = sys.argv[3]

    try:

        resolved_path = os.path.realpath(path)

        if not os.path.exists(resolved_path):
            result = {
                "size": 0,
                "files": 0,
                "error": f"Path does not exist: {resolved_path}"
            }

        elif not os.path.isdir(resolved_path):
            result = {
                "size": 0,
                "files": 0,
                "error": f"Not a directory: {resolved_path}"
            }

        else:
            shallow = (mode == "shallow")

            result = calculate_directory_size(resolved_path, shallow)

            result["original_path"] = path
            result["resolved_path"] = resolved_path
            result["mode"] = mode
            result["timestamp"] = time.time()

    except Exception as e:

        result = {
            "size": 0,
            "files": 0,
            "error": str(e),
            "original_path": path,
            "mode": mode,
            "timestamp": time.time()
        }

    try:
        with open(output_file, "w") as f:
            json.dump(result, f, indent=2)

    except Exception as e:
        print(f"Failed to write output: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()