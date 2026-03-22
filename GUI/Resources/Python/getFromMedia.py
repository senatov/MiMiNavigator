#
//  getFromMedia.py
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//


#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import subprocess
import tempfile
import shutil
from urllib.parse import urlparse, unquote

OUTPUT_FILE = "/tmp/osmic5673.asc"

INSTALL_HINT = """Missing required tools.

Install them using:

brew install exiftool tesseract ffmpeg
pip3 install tabulate
"""


def run(cmd, timeout=60):
    try:
        completed = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout
        )
        if completed.returncode != 0:
            return f"[ERROR]\n{completed.stderr.strip()}"
        return completed.stdout
    except subprocess.TimeoutExpired:
        return "[ERROR] command timeout"


def normalize_path(input_path):
    """Normalize input to a valid filesystem path.
    Supports:
    - plain paths
    - file:// URLs
    - percent-encoded paths
    """
    if not input_path:
        return ""

    # Handle file:// URL
    if input_path.startswith("file://"):
        parsed = urlparse(input_path)
        path = parsed.path
    else:
        path = input_path

    # Decode percent-encoding (e.g. spaces)
    path = unquote(path)

    # Expand ~ if present
    path = os.path.expanduser(path)

    # Normalize path
    path = os.path.normpath(path)

    return path
def log(msg):
    print(f"[getFromMedia] {msg}")

def report_progress(p, message=None):
    try:
        p = int(p)
    except Exception:
        return
    if message:
        print(f"PROGRESS: {p}:{message}", flush=True)
    else:
        print(f"PROGRESS: {p}", flush=True)


def check_tools_or_exit():
    required = ["exiftool", "tesseract", "ffmpeg"]
    missing = []

    for tool in required:
        if not shutil.which(tool):
            missing.append(tool)

    try:
        import tabulate  # noqa
    except ImportError:
        missing.append("tabulate (python)")

    if missing:
        with open(OUTPUT_FILE, "w") as f:
            f.write(INSTALL_HINT)
            f.write("\nMissing:\n")
            for m in missing:
                f.write(f"- {m}\n")
        sys.exit(0)


def extract_metadata(path):
    log(f"extract metadata '{path}'")
    return run(["exiftool", path], timeout=30)


def extract_text_image(path):
    log(f"ocr image '{path}'")
    with tempfile.NamedTemporaryFile(delete=False) as tmp:
        tmp_base = tmp.name

    run(["tesseract", path, tmp_base])
    txt_file = tmp_base + ".txt"

    result = ""
    if os.path.exists(txt_file):
        with open(txt_file) as f:
            result = f.read()

    if len(result) > 20000:
        result = result[:20000] + "\n[TRUNCATED OCR]"

    # Cleanup temp files
    try:
        if os.path.exists(txt_file):
            os.remove(txt_file)
        if os.path.exists(tmp_base):
            os.remove(tmp_base)
    except Exception:
        pass

    return result


def extract_text_video(path):
    log(f"extract video frames from '{path}'")
    tmp_dir = tempfile.mkdtemp()
    frame_pattern = os.path.join(tmp_dir, "frame_%04d.png")

    run(["ffmpeg", "-loglevel", "error", "-i", path, "-vf", "fps=1", frame_pattern], timeout=120)

    texts = []
    max_frames = 20
    for file in sorted(os.listdir(tmp_dir))[:max_frames]:
        if file.endswith(".png"):
            full = os.path.join(tmp_dir, file)
            txt = extract_text_image(full)
            if txt.strip():
                texts.append((file, txt.strip()))

    shutil.rmtree(tmp_dir, ignore_errors=True)
    return texts


def build_table(meta_text):
    from tabulate import tabulate

    if "[ERROR]" in meta_text:
        return "[TABLE SKIPPED DUE TO ERROR]\n"

    table = []
    for line in meta_text.splitlines():
        if ":" in line:
            try:
                key, val = line.split(":", 1)
                table.append([key.strip(), val.strip()])
            except Exception:
                continue

    if not table:
        return "[EMPTY METADATA]\n"

    return tabulate(table, headers=["Field", "Value"], tablefmt="grid")


def main():
    check_tools_or_exit()

    if len(sys.argv) < 2:
        print("Usage: script.py <file_path_or_url>")
        sys.exit(1)

    path = normalize_path(sys.argv[1])
    raw_input = sys.argv[1]
    fast_mode = "--fast" in sys.argv
    log(f"input='{raw_input}' normalized='{path}'")
    report_progress(5, "init")

    if not os.path.exists(path):
        with open(OUTPUT_FILE, "w") as f:
            f.write("File not found\n")
            f.write(f"Input: {raw_input}\n")
            f.write(f"Normalized: {path}\n")
        sys.exit(1)

    result = []
    result.append("=== INPUT ===\n")
    result.append(f"raw: {raw_input}\nnormalized: {path}\n")

    # Metadata
    meta = extract_metadata(path)
    report_progress(20, "metadata")
    result.append("=== METADATA RAW ===\n")
    result.append(meta + "\n")
    if len(meta) > 50000:
        result.append("[TRUNCATED METADATA]\n")

    result.append("=== METADATA TABLE ===\n")
    result.append(build_table(meta) + "\n")
    result.append("\n------------------------------\n")

    ext = os.path.splitext(path)[1].lower()
    log(f"detected extension '{ext}'")

    # Image OCR
    if ext.endswith((".png", ".jpg", ".jpeg", ".heic")):
        report_progress(40, "image OCR start")
        text = extract_text_image(path)
        report_progress(80, "image OCR done")
        result.append("=== OCR TEXT (IMAGE) ===\n")
        result.append(text + "\n")

    # Video OCR
    elif ext.endswith((".mp4", ".mov", ".mkv", ".avi")):
        if fast_mode:
            log("fast mode: skipping video OCR")
            report_progress(60, "video skipped")
            result.append("[FAST MODE] video OCR skipped\n")
        else:
            report_progress(40, "video OCR start")
            texts = extract_text_video(path)
            report_progress(80, "video OCR done")
            result.append("=== OCR TEXT (VIDEO FRAMES) ===\n")

            for fname, txt in texts:
                if len(txt) > 2000:
                    txt = txt[:2000] + "\n[TRUNCATED FRAME OCR]"
                result.append(f"[{fname}]\n{txt}\n\n")

    report_progress(100, "done")
    with open(OUTPUT_FILE, "w") as f:
        f.write("\n".join(result))


if __name__ == "__main__":
    main()
