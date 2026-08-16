#!/usr/bin/env python3

"""Validate dependency identity, source, revision, license, and production scope."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess


REPOSITORY = Path(__file__).resolve().parent.parent


def flatten_dependencies(node: dict[str, object]) -> dict[str, dict[str, object]]:
    flattened: dict[str, dict[str, object]] = {}
    for dependency in node.get("dependencies", []):
        assert isinstance(dependency, dict)
        identity = dependency.get("identity")
        if not isinstance(identity, str):
            raise ValueError("Dependency has no string identity.")
        if identity in flattened:
            raise ValueError(f"Duplicate dependency identity: {identity}")
        flattened[identity] = dependency
        flattened.update(flatten_dependencies(dependency))
    return flattened


def license_identifier(path: Path) -> str:
    candidates = sorted(path.glob("LICENSE*")) + sorted(path.glob("COPYING*"))
    if not candidates:
        raise ValueError(f"No license file in {path}")
    text = candidates[0].read_text(encoding="utf-8", errors="replace")
    if "Apache License" in text and "Version 2.0" in text:
        return "Apache-2.0"
    raise ValueError(f"Unrecognized license in {candidates[0]}")


def main() -> None:
    policy = json.loads(
        (REPOSITORY / "Configuration/DependencyPolicy.json").read_text(
            encoding="utf-8"
        )
    )
    graph = json.loads(
        subprocess.check_output(
            ["swift", "package", "show-dependencies", "--format", "json"],
            cwd=REPOSITORY,
            text=True,
        )
    )
    dependencies = flatten_dependencies(graph)
    expected = policy["dependencies"]
    unexpected = set(dependencies) - set(expected)
    missing = {
        identity
        for identity, rule in expected.items()
        if rule.get("required", True) and identity not in dependencies
    }
    if unexpected or missing:
        raise SystemExit(
            f"Resolved dependency policy mismatch: unexpected={sorted(unexpected)}, "
            f"missing={sorted(missing)}."
        )

    resolved = json.loads((REPOSITORY / "Package.resolved").read_text(encoding="utf-8"))
    pins = {pin["identity"]: pin for pin in resolved["pins"]}
    if set(pins) != set(expected):
        raise SystemExit(
            f"Package.resolved pins {sorted(pins)} differ from policy {sorted(expected)}."
        )
    for identity, pin in pins.items():
        rule = expected[identity]
        if pin["location"] != rule["url"]:
            raise SystemExit(f"Unexpected pinned source URL for {identity}: {pin['location']}")
        if pin["state"]["revision"] != rule["revision"]:
            raise SystemExit(
                f"Unexpected pinned revision for {identity}: "
                f"{pin['state']['revision']}"
            )

    allowed_licenses = set(policy["allowedLicenses"])
    for identity, dependency in dependencies.items():
        rule = expected[identity]
        if dependency["url"] != rule["url"]:
            raise SystemExit(f"Unexpected source URL for {identity}: {dependency['url']}")
        checkout = Path(str(dependency["path"]))
        revision = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=checkout, text=True
        ).strip()
        if revision != rule["revision"]:
            raise SystemExit(
                f"Unexpected revision for {identity}: {revision}; expected {rule['revision']}"
            )
        detected_license = license_identifier(checkout)
        if detected_license != rule["license"] or detected_license not in allowed_licenses:
            raise SystemExit(f"Disallowed license for {identity}: {detected_license}")

    manifest = json.loads(
        subprocess.check_output(
            ["swift", "package", "dump-package"], cwd=REPOSITORY, text=True
        )
    )
    production_names = {"P5", "Matter", "ML5"}
    for target in manifest["targets"]:
        if target["name"] in production_names and target["dependencies"]:
            raise SystemExit(f"Production target {target['name']} has a dependency.")
    print(
        f"Dependency policy valid: {len(dependencies)} active and {len(pins)} pinned "
        "test-only Apache-2.0 dependencies."
    )


if __name__ == "__main__":
    main()
