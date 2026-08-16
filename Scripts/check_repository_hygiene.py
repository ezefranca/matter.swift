#!/usr/bin/env python3

"""Reject generated user state and verify intentional shared artifacts."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess


REPOSITORY = Path(__file__).resolve().parent.parent
DISALLOWED_PARTS = {
    ".build",
    ".DS_Store",
    "DerivedData",
    "xcuserdata",
    "UserInterfaceState.xcuserstate",
}
DISALLOWED_SUFFIXES = (".profraw", ".profdata", ".xcresult", ".trace", ".netrc")


def tracked_files() -> list[Path]:
    output = subprocess.check_output(
        ["git", "ls-files", "-z"], cwd=REPOSITORY
    ).decode("utf-8")
    return [Path(value) for value in output.split("\0") if value]


def main() -> None:
    boundaries = json.loads(
        (REPOSITORY / "Configuration/ModuleBoundaries.json").read_text(
            encoding="utf-8"
        )
    )
    products = tuple(boundaries["products"])
    violations: list[str] = []
    for path in tracked_files():
        if any(part in DISALLOWED_PARTS for part in path.parts):
            violations.append(str(path))
        if path.name.endswith(DISALLOWED_SUFFIXES):
            violations.append(str(path))

    required = [
        Path("Documentation/RepositoryHygiene.md"),
        Path("Package.resolved"),
        Path("Package.swift"),
        Path("THIRD_PARTY_NOTICES.md"),
    ]
    demo_project = Path("P5Demo/P5Demo.xcodeproj/project.pbxproj")
    if (REPOSITORY / "P5Demo").is_dir():
        required.append(demo_project)
    for product in products:
        required.extend(
            [
                Path(f".swiftpm/xcode/xcshareddata/xcschemes/{product}.xcscheme"),
                Path(f".swiftpm/xcode/xcshareddata/xctestplans/{product}.xctestplan"),
                Path(f"Documentation/APIBaselines/{product}.json"),
                Path(f"Sources/{product}/Resources/PrivacyInfo.xcprivacy"),
            ]
        )
    missing = [str(path) for path in required if not (REPOSITORY / path).is_file()]

    if violations:
        raise SystemExit("Disallowed tracked generated state:\n- " + "\n- ".join(violations))
    if missing:
        raise SystemExit("Missing intentional repository artifacts:\n- " + "\n- ".join(missing))
    print(f"Repository hygiene valid: {len(required)} required artifacts, no user state.")


if __name__ == "__main__":
    main()
