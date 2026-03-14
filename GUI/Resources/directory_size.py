#!/usr/bin/env python3
"""
Fast directory size calculator for MiMiNavigator
Handles symlinks, cloud directories (OneDrive, iCloud), and regular directories
Outputs JSON results to /tmp for Swift to read
"""

import os
import sys
import json
import time


def calculate_directory_size(path, shallow=False):
    total_size = 0
    file_count = 0

    try:

        if shallow:
            # fast first-level scan
            with os.scandir(path) as it:
                for entry in it:
                    try:
                        if entry.is_file(follow_symlinks=False):
                            total_size += entry.stat(follow_symlinks=False).st_size
                            file_count += 1
                    except (OSError, PermissionError):
                        continue

        else:
            # full recursive scan
            for root, dirs, files in os.walk(
                path,
                topdown=True,
                followlinks=True   # IMPORTANT for OneDrive / iCloud
            ):

                # remove problematic dirs
                dirs[:] = [d for d in dirs if d not in ('.git', '.cache')]

                for name in files:
                    file_path = os.path.join(root, name)

                    try:
                        st = os.stat(file_path, follow_symlinks=False)
                        total_size += st.st_size
                        file_count += 1
                    except (OSError, PermissionError):
                        continue

        return {
            "size": total_size,
            "files": file_count,
            "error": None
        }

    except Exception as e:
        return {
            "size": 0,
            "files": 0,
            "error": str(e)
        }


def main():

    if len(sys.argv) != 4:
        print(
            "Usage: directory_size.py <path> <shallow|full> <output_file>",
            file=sys.stderr
        )
        sys.exit(1)

    path = sys.argv[1]
    mode = sys.argv[2]
    output_file = sys.argv[3]

    start = time.time()

    try:

        resolved_path = os.path.realpath(path)

        if not os.path.exists(resolved_path):
            result = {"size": 0, "files": 0, "error": "path not found"}

        elif not os.path.isdir(resolved_path):
            result = {"size": 0, "files": 0, "error": "not directory"}

        else:

            shallow = mode == "shallow"

            result = calculate_directory_size(
                resolved_path,
                shallow=shallow
            )

            result["original_path"] = path
            result["resolved_path"] = resolved_path
            result["mode"] = mode
            result["duration"] = time.time() - start
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
            json.dump(result, f)
    except Exception as e:
        print(f"Failed to write output: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()