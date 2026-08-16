#!/usr/bin/env python3

"""Require reciprocal package-family links without depending on sibling checkouts."""

from __future__ import annotations

import json
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parent.parent
FAMILY = {
    "p5.swift": "P5",
    "matter.swift": "Matter",
    "ml5.swift": "ML5",
}


def main() -> None:
    repository_name = REPOSITORY.name
    if repository_name not in FAMILY:
        raise SystemExit(f"Unknown package-family repository {repository_name}.")
    boundaries = json.loads(
        (REPOSITORY / "Configuration/ModuleBoundaries.json").read_text(
            encoding="utf-8"
        )
    )
    products = list(boundaries["products"])
    expected_product = FAMILY[repository_name]
    if products != [expected_product]:
        raise SystemExit(
            f"{repository_name} must contain only the {expected_product} product."
        )

    readme = (REPOSITORY / "README.md").read_text(encoding="utf-8")
    landing = (
        REPOSITORY / "Sources" / expected_product / f"{expected_product}.docc"
        / f"{expected_product}.md"
    ).read_text(encoding="utf-8")
    failures: list[str] = []
    for sibling in FAMILY:
        if sibling == repository_name:
            continue
        url = f"https://github.com/ezefranca/{sibling}"
        if url not in readme:
            failures.append(f"README.md is missing {url}")
        if url not in landing:
            failures.append(f"DocC landing page is missing {url}")
    if failures:
        raise SystemExit("Package-family link failures:\n- " + "\n- ".join(failures))
    print(
        f"Package-family topology valid: {repository_name} owns {expected_product} "
        "and links both independent siblings."
    )


if __name__ == "__main__":
    main()
