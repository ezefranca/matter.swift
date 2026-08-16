#!/usr/bin/env python3

"""Validate each product's packaged Apple privacy manifest."""

from __future__ import annotations

import json
from pathlib import Path
import plistlib
import subprocess


REPOSITORY = Path(__file__).resolve().parent.parent
PRODUCT_ACCESS = {
    "P5": {"NSPrivacyAccessedAPICategorySystemBootTime": {"35F9.1"}},
    "Matter": {},
    "ML5": {},
}


def validate_manifest(
    path: Path,
    expected_access: dict[str, set[str]],
) -> None:
    with path.open("rb") as manifest_file:
        manifest = plistlib.load(manifest_file)

    required_keys = {
        "NSPrivacyAccessedAPITypes",
        "NSPrivacyCollectedDataTypes",
        "NSPrivacyTracking",
    }
    if set(manifest) != required_keys:
        raise ValueError(
            f"{path} keys {sorted(manifest)} differ from {sorted(required_keys)}."
        )
    if manifest["NSPrivacyTracking"] is not False:
        raise ValueError(f"{path} must declare tracking as false.")
    if manifest["NSPrivacyCollectedDataTypes"] != []:
        raise ValueError(f"{path} must not declare package-level data collection.")

    actual_access: dict[str, set[str]] = {}
    for entry in manifest["NSPrivacyAccessedAPITypes"]:
        if set(entry) != {
            "NSPrivacyAccessedAPIType",
            "NSPrivacyAccessedAPITypeReasons",
        }:
            raise ValueError(f"{path} contains a malformed accessed-API entry.")
        category = entry["NSPrivacyAccessedAPIType"]
        reasons = set(entry["NSPrivacyAccessedAPITypeReasons"])
        if not isinstance(category, str) or not reasons or not all(
            isinstance(reason, str) for reason in reasons
        ):
            raise ValueError(f"{path} contains an invalid category or reason.")
        if category in actual_access:
            raise ValueError(f"{path} repeats category {category}.")
        actual_access[category] = reasons

    if actual_access != expected_access:
        raise ValueError(
            f"{path} accessed APIs {actual_access} differ from {expected_access}."
        )


def main() -> None:
    package = json.loads(
        subprocess.check_output(
            ["swift", "package", "dump-package"],
            cwd=REPOSITORY,
            text=True,
        )
    )
    targets = {target["name"]: target for target in package["targets"]}
    for product, expected_access in PRODUCT_ACCESS.items():
        relative_path = Path("Resources/PrivacyInfo.xcprivacy")
        resources = {
            resource["path"]: resource["rule"] for resource in targets[product]["resources"]
        }
        if resources.get(str(relative_path)) != {"process": {}}:
            raise SystemExit(f"{product} must process {relative_path} as a resource.")
        path = REPOSITORY / "Sources" / product / relative_path
        try:
            validate_manifest(path, expected_access)
        except (OSError, plistlib.InvalidFileException, ValueError) as error:
            raise SystemExit(str(error)) from error

    print("Privacy manifests valid for P5, Matter, and ML5.")


if __name__ == "__main__":
    main()
