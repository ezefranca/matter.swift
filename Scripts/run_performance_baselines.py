#!/usr/bin/env python3

"""Run representative product workloads against generous regression budgets."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import time


REPOSITORY = Path(__file__).resolve().parent.parent


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-build", action="store_true")
    arguments = parser.parse_args()
    configuration = json.loads(
        (REPOSITORY / "Configuration/PerformanceBudgets.json").read_text(
            encoding="utf-8"
        )
    )
    if not arguments.skip_build:
        subprocess.run(
            ["swift", "test", "list", "-Xswiftc", "-warnings-as-errors"],
            cwd=REPOSITORY,
            check=True,
        )

    results = []
    failed = False
    for baseline in configuration["baselines"]:
        started = time.monotonic()
        subprocess.run(
            [
                "swift",
                "test",
                "--skip-build",
                "--filter",
                baseline["filter"],
            ],
            cwd=REPOSITORY,
            check=True,
        )
        duration = time.monotonic() - started
        passed = duration <= baseline["maximumSeconds"]
        failed = failed or not passed
        results.append(
            {
                "name": baseline["name"],
                "seconds": round(duration, 6),
                "maximumSeconds": baseline["maximumSeconds"],
                "passed": passed,
            }
        )
    print(json.dumps({"schemaVersion": 1, "results": results}, indent=2))
    if failed:
        raise SystemExit("One or more performance baselines exceeded their budget.")


if __name__ == "__main__":
    main()
