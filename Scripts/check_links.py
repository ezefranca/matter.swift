#!/usr/bin/env python3

"""Validate Markdown links locally and optionally probe external references."""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import re
import urllib.error
import urllib.parse
import urllib.request


REPOSITORY = Path(__file__).resolve().parent.parent
LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
HEADING = re.compile(r"^#{1,6}\s+(.+?)\s*$", re.MULTILINE)


def anchor(value: str) -> str:
    value = re.sub(r"[`*_~]", "", value).strip().lower()
    value = re.sub(r"[^\w\- ]", "", value)
    return re.sub(r"[\s-]+", "-", value).strip("-")


def markdown_files() -> list[Path]:
    return sorted(
        path
        for path in REPOSITORY.rglob("*.md")
        if ".build" not in path.parts and ".git" not in path.parts
    )


def local_failures() -> tuple[list[str], set[str]]:
    failures: list[str] = []
    external: set[str] = set()
    for source in markdown_files():
        text = source.read_text(encoding="utf-8")
        for raw in LINK.findall(text):
            destination = raw.strip().split(maxsplit=1)[0].strip("<>")
            parsed = urllib.parse.urlparse(destination)
            if parsed.scheme in {"http", "https"}:
                external.add(destination)
                continue
            if parsed.scheme or destination.startswith("mailto:"):
                continue
            path_text, _, fragment = destination.partition("#")
            target = source if not path_text else (source.parent / urllib.parse.unquote(path_text))
            target = target.resolve()
            if not target.exists():
                failures.append(f"{source.relative_to(REPOSITORY)} -> missing {destination}")
                continue
            if fragment and target.suffix.lower() == ".md":
                headings = {
                    anchor(value)
                    for value in HEADING.findall(target.read_text(encoding="utf-8"))
                }
                if urllib.parse.unquote(fragment).lower() not in headings:
                    failures.append(
                        f"{source.relative_to(REPOSITORY)} -> missing anchor {destination}"
                    )
    return failures, external


def probe(url: str) -> str | None:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "p5.swift-link-check/1.0"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            if response.status >= 400:
                return f"{url} -> HTTP {response.status}"
    except (urllib.error.URLError, TimeoutError) as error:
        return f"{url} -> {error}"
    return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--online", action="store_true")
    arguments = parser.parse_args()
    failures, external = local_failures()
    if arguments.online:
        with ThreadPoolExecutor(max_workers=8) as executor:
            failures.extend(result for result in executor.map(probe, sorted(external)) if result)
    if failures:
        raise SystemExit("Broken documentation links:\n- " + "\n- ".join(failures))
    mode = "local and external" if arguments.online else "local"
    print(f"Documentation links valid ({mode}); {len(external)} external URLs discovered.")


if __name__ == "__main__":
    main()
