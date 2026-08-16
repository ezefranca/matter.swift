#!/usr/bin/env python3

"""Require immutable revisions and least-privilege declarations in workflows."""

from __future__ import annotations

from pathlib import Path
import re


REPOSITORY = Path(__file__).resolve().parent.parent
ACTION = re.compile(r"^\s*uses:\s*([^\s#]+)", re.MULTILINE)
IMMUTABLE_ACTION = re.compile(r"^[^@]+@[0-9a-f]{40}$")


def failures_for(text: str, name: str) -> list[str]:
    failures: list[str] = []
    for action in ACTION.findall(text):
        if action.startswith("./"):
            continue
        if not IMMUTABLE_ACTION.fullmatch(action):
            failures.append(f"{name}: action is not pinned to a commit: {action}")
    if "permissions:" not in text:
        failures.append(f"{name}: no explicit permissions declaration")
    return failures


def main() -> None:
    failures: list[str] = []
    workflows = sorted((REPOSITORY / ".github/workflows").glob("*.yml"))
    for path in workflows:
        failures.extend(
            failures_for(path.read_text(encoding="utf-8"), path.name)
        )
    if failures:
        raise SystemExit("Workflow security violations:\n- " + "\n- ".join(failures))
    print(f"Workflow security valid: {len(workflows)} workflows use immutable actions.")


if __name__ == "__main__":
    main()
