#!/usr/bin/env python3

"""Require complete line coverage for production Swift sources."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--coverage", required=True, type=Path)
    parser.add_argument("--source-root", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    options = arguments()
    coverage_path = options.coverage.resolve()
    source_root = options.source_root.resolve()
    payload = json.loads(coverage_path.read_text(encoding="utf-8"))

    files = payload["data"][0]["files"]
    source_files = [
        item
        for item in files
        if Path(item["filename"]).resolve().is_relative_to(source_root)
    ]
    if not source_files:
        raise SystemExit(f"No coverage data found below {source_root}.")

    uncovered = []
    covered_lines = 0
    total_lines = 0
    for item in source_files:
        lines = item["summary"]["lines"]
        covered_lines += lines["covered"]
        total_lines += lines["count"]
        if lines["covered"] != lines["count"]:
            uncovered.append(
                f"{item['filename']}: "
                f"{lines['covered']}/{lines['count']} lines"
            )

    percentage = covered_lines / total_lines * 100
    print(
        f"P5 line coverage: {covered_lines}/{total_lines} "
        f"({percentage:.2f}%)"
    )

    if uncovered:
        details = "\n".join(f"- {entry}" for entry in uncovered)
        raise SystemExit(f"Line coverage must be 100%:\n{details}")


if __name__ == "__main__":
    main()
