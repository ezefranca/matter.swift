#!/usr/bin/env python3

"""Create a deterministic release manifest with source artifact checksums."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess


REPOSITORY = Path(__file__).resolve().parent.parent


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("artifacts", nargs="+", type=Path)
    arguments = parser.parse_args()
    commit = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=REPOSITORY, text=True
    ).strip()
    artifacts = []
    for path in sorted(arguments.artifacts, key=lambda value: value.name):
        artifacts.append(
            {"name": path.name, "bytes": path.stat().st_size, "sha256": sha256(path)}
        )
    payload = {
        "schemaVersion": 1,
        "tag": arguments.tag,
        "commit": commit,
        "products": ["P5", "Matter", "ML5"],
        "artifacts": artifacts,
    }
    arguments.output.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
