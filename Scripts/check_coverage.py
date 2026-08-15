#!/usr/bin/env python3

"""Require complete line and expression-region coverage for Swift sources."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--coverage", required=True, type=Path)
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--minimum", default=100.0, type=float)
    parser.add_argument("--minimum-regions", default=100.0, type=float)
    return parser.parse_args()


def main() -> None:
    options = arguments()
    coverage_path = options.coverage.resolve()
    source_root = options.source_root.resolve()
    if not 0 <= options.minimum <= 100:
        raise SystemExit("--minimum must be between 0 and 100.")
    if not 0 <= options.minimum_regions <= 100:
        raise SystemExit("--minimum-regions must be between 0 and 100.")
    payload = json.loads(coverage_path.read_text(encoding="utf-8"))

    files = payload["data"][0]["files"]
    source_files = [
        item
        for item in files
        if Path(item["filename"]).resolve().is_relative_to(source_root)
    ]
    if not source_files:
        raise SystemExit(f"No coverage data found below {source_root}.")

    uncovered_lines = []
    uncovered_regions = []
    covered_lines = 0
    total_lines = 0
    covered_regions = 0
    total_regions = 0
    for item in source_files:
        lines = item["summary"]["lines"]
        regions = item["summary"]["regions"]
        covered_lines += lines["covered"]
        total_lines += lines["count"]
        covered_regions += regions["covered"]
        total_regions += regions["count"]
        if lines["covered"] != lines["count"]:
            uncovered_lines.append(
                f"{item['filename']}: "
                f"{lines['covered']}/{lines['count']} lines"
            )
        if regions["covered"] != regions["count"]:
            uncovered_regions.append(
                f"{item['filename']}: "
                f"{regions['covered']}/{regions['count']} regions"
            )

    percentage = covered_lines / total_lines * 100
    region_percentage = covered_regions / total_regions * 100
    target_name = source_root.name
    print(
        f"{target_name} line coverage: {covered_lines}/{total_lines} "
        f"({percentage:.2f}%)"
    )
    print(
        f"{target_name} region coverage: {covered_regions}/{total_regions} "
        f"({region_percentage:.2f}%)"
    )

    if percentage + 0.000_001 < options.minimum:
        details = "\n".join(f"- {entry}" for entry in uncovered_lines)
        raise SystemExit(
            f"Line coverage must be at least {options.minimum:.2f}%:\n{details}"
        )
    if region_percentage + 0.000_001 < options.minimum_regions:
        details = "\n".join(f"- {entry}" for entry in uncovered_regions)
        raise SystemExit(
            "Region coverage must be at least "
            f"{options.minimum_regions:.2f}%:\n{details}"
        )


if __name__ == "__main__":
    main()
