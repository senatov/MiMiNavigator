#!/usr/bin/env python3
# -*- coding: utf-8 -*-

#using: python3 generate_oui_vendors.py --input ~/Downloads/ieee --output ./oui-vendors.txt

"""
generate_oui_vendors.py

Builds oui-vendors.txt from local IEEE CSV exports.

Supported sources:
- MA-L
- CID
- optionally MA-M / MA-S (collapsed to 6 hex chars, less precise)

Output format:
# prefix|vendor
000C29|VMware, Inc.

Usage examples:
    python3 generate_oui_vendors.py \
        --input ~/Downloads/ieee \
        --output ./oui-vendors.txt

    python3 generate_oui_vendors.py \
        --input ~/Downloads/ieee \
        --output ./oui-vendors.txt \
        --include-ma-m \
        --include-ma-s
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path
from typing import Iterable


HEX_RE = re.compile(r"[^0-9A-Fa-f]")


def normalize_hex(value: str) -> str:
    return HEX_RE.sub("", value).upper()


def clean_vendor_name(value: str) -> str:
    return " ".join(value.strip().split())


def find_candidate_csv_files(root: Path) -> list[Path]:
    if not root.exists():
        raise FileNotFoundError(f"Input directory does not exist: {root}")

    files = [p for p in root.rglob("*.csv") if p.is_file()]
    if not files:
        raise FileNotFoundError(f"No CSV files found under: {root}")

    return sorted(files)


def classify_file(path: Path) -> str:
    name = path.name.lower()

    if "mal" in name or "ma-l" in name or "oui" in name:
        return "MA-L"
    if "cid" in name:
        return "CID"
    if "mam" in name or "ma-m" in name:
        return "MA-M"
    if "mas" in name or "ma-s" in name:
        return "MA-S"

    return "UNKNOWN"


def header_map(fieldnames: Iterable[str] | None) -> dict[str, str]:
    if not fieldnames:
        return {}
    result: dict[str, str] = {}
    for name in fieldnames:
        key = normalize_header(name)
        result[key] = name
    return result


def normalize_header(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", name.strip().lower())


def pick_column(columns: dict[str, str], candidates: list[str]) -> str | None:
    for candidate in candidates:
        if candidate in columns:
            return columns[candidate]
    return None


def detect_columns(fieldnames: Iterable[str] | None) -> tuple[str | None, str | None]:
    columns = header_map(fieldnames)

    assignment_col = pick_column(
        columns,
        [
            "assignment",
            "macaddressblocklarge",
            "macaddressblockmedium",
            "macaddressblocksmall",
            "cid",
            "registryassignment",
        ],
    )

    vendor_col = pick_column(
        columns,
        [
            "organizationname",
            "organization",
            "companyname",
            "name",
            "registrantorganization",
        ],
    )

    return assignment_col, vendor_col


def iter_rows(csv_path: Path) -> Iterable[dict[str, str]]:
    with csv_path.open("r", encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            yield row


def parse_csv_file(
    csv_path: Path,
    source_type: str,
    include_ma_m: bool,
    include_ma_s: bool,
) -> dict[str, str]:
    result: dict[str, str] = {}

    with csv_path.open("r", encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        assignment_col, vendor_col = detect_columns(reader.fieldnames)

        if not assignment_col or not vendor_col:
            print(
                f"[WARN] Skipping {csv_path.name}: could not detect required columns",
                file=sys.stderr,
            )
            return result

        for row in reader:
            raw_assignment = (row.get(assignment_col) or "").strip()
            raw_vendor = clean_vendor_name(row.get(vendor_col) or "")

            if not raw_assignment or not raw_vendor:
                continue

            normalized = normalize_hex(raw_assignment)
            if not normalized:
                continue

            prefix6 = normalized[:6]
            if len(prefix6) != 6:
                continue

            if source_type == "MA-L":
                result.setdefault(prefix6, raw_vendor)
                continue

            if source_type == "CID":
                result.setdefault(prefix6, raw_vendor)
                continue

            if source_type == "MA-M":
                if include_ma_m:
                    result.setdefault(prefix6, raw_vendor)
                continue

            if source_type == "MA-S":
                if include_ma_s:
                    result.setdefault(prefix6, raw_vendor)
                continue

    return result


def merge_sources(
    csv_files: list[Path],
    include_ma_m: bool,
    include_ma_s: bool,
) -> dict[str, str]:
    merged: dict[str, str] = {}

    priority = ["MA-L", "CID", "MA-M", "MA-S", "UNKNOWN"]

    grouped: dict[str, list[Path]] = {key: [] for key in priority}
    for path in csv_files:
        grouped.setdefault(classify_file(path), []).append(path)

    for source_type in priority:
        for path in grouped.get(source_type, []):
            parsed = parse_csv_file(
                path,
                source_type=source_type,
                include_ma_m=include_ma_m,
                include_ma_s=include_ma_s,
            )
            for prefix, vendor in parsed.items():
                merged.setdefault(prefix, vendor)

    return merged


def write_output(data: dict[str, str], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("w", encoding="utf-8", newline="\n") as fh:
        fh.write("# prefix|vendor\n")
        for prefix in sorted(data):
            fh.write(f"{prefix}|{data[prefix]}\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate oui-vendors.txt from local IEEE CSV files."
    )
    parser.add_argument(
        "--input",
        required=True,
        help="Directory containing downloaded IEEE CSV files.",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Path to output oui-vendors.txt",
    )
    parser.add_argument(
        "--include-ma-m",
        action="store_true",
        help="Also include MA-M rows collapsed to 6 hex chars.",
    )
    parser.add_argument(
        "--include-ma-s",
        action="store_true",
        help="Also include MA-S rows collapsed to 6 hex chars.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    input_dir = Path(args.input).expanduser().resolve()
    output_file = Path(args.output).expanduser().resolve()

    try:
        csv_files = find_candidate_csv_files(input_dir)
        merged = merge_sources(
            csv_files=csv_files,
            include_ma_m=args.include_ma_m,
            include_ma_s=args.include_ma_s,
        )
        write_output(merged, output_file)
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    print(f"[OK] CSV files found: {len(csv_files)}")
    print(f"[OK] Prefixes written: {len(merged)}")
    print(f"[OK] Output: {output_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())