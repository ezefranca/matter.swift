#!/usr/bin/env python3

"""Validate the package manifest and repository against machine-readable policy."""

from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess


REPOSITORY = Path(__file__).resolve().parent.parent


def version_tuple(value: str) -> tuple[int, ...]:
    return tuple(int(component) for component in value.split("."))


def main() -> None:
    support = json.loads(
        (REPOSITORY / "Configuration/SupportPolicy.json").read_text(encoding="utf-8")
    )
    boundaries = json.loads(
        (REPOSITORY / "Configuration/ModuleBoundaries.json").read_text(
            encoding="utf-8"
        )
    )
    package = json.loads(
        subprocess.check_output(
            ["swift", "package", "dump-package"],
            cwd=REPOSITORY,
            text=True,
        )
    )

    expected_products = set(boundaries["products"])
    actual_products = {
        product["name"]
        for product in package["products"]
        if "library" in product["type"]
    }
    if actual_products != expected_products:
        raise SystemExit(
            f"Library products {sorted(actual_products)} do not match policy "
            f"{sorted(expected_products)}."
        )

    targets = {target["name"]: target for target in package["targets"]}
    for product, boundary in boundaries["products"].items():
        source_root = REPOSITORY / boundary["sourceRoot"]
        test_root = REPOSITORY / boundary["testRoot"]
        if not source_root.is_dir() or not test_root.is_dir():
            raise SystemExit(f"Missing source or test ownership root for {product}.")
        dependencies = targets[product]["dependencies"]
        if dependencies != boundary["allowedProductionDependencies"]:
            raise SystemExit(
                f"{product} dependencies {dependencies} violate its boundary policy."
            )
        scheme = (
            REPOSITORY
            / ".swiftpm/xcode/xcshareddata/xcschemes"
            / f"{product}.xcscheme"
        )
        if not scheme.is_file():
            raise SystemExit(f"Missing shared Xcode scheme for {product}.")
        test_plan = (
            REPOSITORY
            / ".swiftpm/xcode/xcshareddata/xctestplans"
            / f"{product}.xctestplan"
        )
        if not test_plan.is_file():
            raise SystemExit(f"Missing shared Xcode test plan for {product}.")

    tools_version = package["toolsVersion"]["_version"].removesuffix(".0")
    if tools_version != support["swift"]["toolsVersion"]:
        raise SystemExit(
            f"Package tools version {tools_version} differs from support policy."
        )
    if package["swiftLanguageVersions"] != [support["swift"]["languageMode"]]:
        raise SystemExit("Swift language mode differs from support policy.")

    actual_platforms = {
        platform["platformName"].lower(): platform["version"]
        for platform in package["platforms"]
    }
    expected_platforms = {
        name.lower(): policy["minimumVersion"]
        for name, policy in support["platforms"].items()
    }
    if actual_platforms != expected_platforms:
        raise SystemExit(
            f"Manifest platforms {actual_platforms} differ from policy "
            f"{expected_platforms}."
        )

    swift_version_output = subprocess.check_output(
        ["swift", "--version"], text=True
    )
    match = re.search(r"Swift version (\d+\.\d+(?:\.\d+)?)", swift_version_output)
    if match is None:
        raise SystemExit("Unable to parse the active Swift version.")
    active_version = version_tuple(match.group(1))
    minimum_version = version_tuple(support["swift"]["minimumTestedVersion"])
    current_version = version_tuple(support["swift"]["currentTestedVersion"])
    if not minimum_version <= active_version <= current_version:
        raise SystemExit(
            f"Active Swift {match.group(1)} is outside the tested range "
            f"{support['swift']['minimumTestedVersion']}–"
            f"{support['swift']['currentTestedVersion']}."
        )

    spi = (REPOSITORY / ".spi.yml").read_text(encoding="utf-8")
    for product in expected_products:
        if f"documentation_targets: [{product}]" not in spi:
            raise SystemExit(
                f"Swift Package Index must build {product} documentation."
            )

    workflow = (REPOSITORY / ".github/workflows/tests.yml").read_text(
        encoding="utf-8"
    )
    expected_runner = f"macos-{support['xcode']['currentMajorVersion']}"
    if expected_runner not in workflow:
        raise SystemExit(f"CI does not exercise the policy runner {expected_runner}.")

    print(
        "Support policy valid: "
        f"Swift {match.group(1)}, {len(expected_products)} independent product, "
        f"iOS {actual_platforms['ios']}+, macOS {actual_platforms['macos']}+."
    )


if __name__ == "__main__":
    main()
