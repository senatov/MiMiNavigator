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
from pathlib import Path

def calculate_directory_size(path, shallow=False):
    """Calculate directory size with optional shallow mode"""
    try:
        total_size = 0
        file_count = 0
        
        if shallow:
            # Shallow: only immediate files, no subdirectories
            try:
                for item in os.listdir(path):
                    item_path = os.path.join(path, item)
                    if os.path.isfile(item_path):
                        total_size += os.path.getsize(item_path)
                        file_count += 1
            except (OSError, PermissionError) as e:
                return {"size": 0, "files": 0, "error": str(e)}
        else:
            # Full recursive
            try:
                for root, dirs, files in os.walk(path):
                    for file in files:
                        try:
                            file_path = os.path.join(root, file)
                            size = os.path.getsize(file_path)
                            total_size += size
                            file_count += 1
                        except (OSError, PermissionError):
                            # Skip files we can't access
                            continue
            except (OSError, PermissionError) as e:
                return {"size": 0, "files": 0, "error": str(e)}
        
        return {"size": total_size, "files": file_count, "error": None}
        
    except Exception as e:
        return {"size": 0, "files": 0, "error": str(e)}

def main():
    if len(sys.argv) != 4:
        print("Usage: directory_size.py <path> <shallow|full> <output_file>", file=sys.stderr)
        sys.exit(1)
    
    path = sys.argv[1]
    mode = sys.argv[2]  # "shallow" or "full"
    output_file = sys.argv[3]
    
    # Resolve symlinks
    try:
        resolved_path = os.path.realpath(path)
        if not os.path.exists(resolved_path):
            result = {"size": 0, "files": 0, "error": f"Path does not exist: {resolved_path}"}
        elif not os.path.isdir(resolved_path):
            result = {"size": 0, "files": 0, "error": f"Not a directory: {resolved_path}"}
        else:
            shallow = (mode == "shallow")
            result = calculate_directory_size(resolved_path, shallow=shallow)
            # Add metadata
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
    
    # Write result to JSON file
    try:
        with open(output_file, 'w') as f:
            json.dump(result, f, indent=2)
    except Exception as e:
        print(f"Failed to write output: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
