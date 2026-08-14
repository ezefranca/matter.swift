#!/usr/bin/env python3

"""Prepare a DocC static export for humans, crawlers, and coding agents."""

from __future__ import annotations

import argparse
import datetime as dt
import html
import json
from pathlib import Path
from urllib.parse import quote


PACKAGE_NAME = "p5.swift"
MODULE_NAME = "p5"


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--site", required=True, type=Path)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--repository-root", default=Path.cwd(), type=Path)
    parser.add_argument("--repository-url", required=True)
    return parser.parse_args()


def abstract_text(document: dict[str, object]) -> str:
    fragments = document.get("abstract", [])
    if not isinstance(fragments, list):
        return "Native p5 creative coding for Swift."
    text = "".join(
        fragment.get("text", "")
        for fragment in fragments
        if isinstance(fragment, dict) and isinstance(fragment.get("text"), str)
    )
    return text or "Native p5 creative coding for Swift."


def route_path(document: dict[str, object]) -> str | None:
    variants = document.get("variants", [])
    if not isinstance(variants, list):
        return None
    for variant in variants:
        if not isinstance(variant, dict):
            continue
        paths = variant.get("paths", [])
        if isinstance(paths, list) and paths and isinstance(paths[0], str):
            return paths[0]
    return None


def seo_shell(
    template: str,
    title: str,
    description: str,
    canonical_url: str,
) -> str:
    safe_title = html.escape(title)
    safe_description = html.escape(description, quote=True)
    safe_url = html.escape(canonical_url, quote=True)
    metadata = (
        f"<title>{safe_title} | {PACKAGE_NAME}</title>"
        f'<meta name="description" content="{safe_description}">'
        f'<link rel="canonical" href="{safe_url}">'
        '<meta property="og:type" content="article">'
        f'<meta property="og:title" content="{safe_title} | {PACKAGE_NAME}">'
        f'<meta property="og:description" content="{safe_description}">'
        f'<meta property="og:url" content="{safe_url}">'
        '<meta name="twitter:card" content="summary">'
    )
    return template.replace("<title>Documentation</title>", metadata, 1)


def landing_shell(template: str, documentation_url: str) -> str:
    safe_url = html.escape(documentation_url, quote=True)
    javascript_url = json.dumps(documentation_url)
    root_url = documentation_url.removesuffix(f"documentation/{MODULE_NAME}/")
    metadata = (
        f"<title>{PACKAGE_NAME} Documentation</title>"
        '<meta name="description" content="Native p5 creative coding for Swift, SwiftUI, UIKit, and AppKit.">'
        f'<link rel="canonical" href="{safe_url}">'
        f'<link rel="alternate" type="text/plain" href="{root_url}llms.txt" title="{PACKAGE_NAME} documentation for language models">'
        f'<meta http-equiv="refresh" content="0; url={safe_url}">'
        '<meta property="og:type" content="website">'
        f'<meta property="og:title" content="{PACKAGE_NAME} Documentation">'
        '<meta property="og:description" content="Native p5 creative coding for Swift, with a roadmap toward broad p5.js capability parity.">'
        f'<meta property="og:url" content="{safe_url}">'
        '<meta name="twitter:card" content="summary">'
        f"<script>window.location.replace({javascript_url});</script>"
    )
    return template.replace("<title>Documentation</title>", metadata, 1)


def encoded_url(base_url: str, route: str) -> str:
    encoded_route = "/".join(
        quote(component, safe="():,_-") for component in route.split("/")
    )
    return f"{base_url}{encoded_route.rstrip('/')}/"


def write_route_pages(
    site: Path,
    base_url: str,
    template: str,
) -> list[dict[str, str]]:
    routes: dict[str, dict[str, str]] = {}
    data_root = site / "data" / "documentation"
    for source in sorted(data_root.rglob("*.json")):
        try:
            document = json.loads(source.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue

        route = route_path(document)
        if not route or not route.startswith("/documentation/"):
            continue

        metadata = document.get("metadata", {})
        title = (
            metadata.get("title", PACKAGE_NAME)
            if isinstance(metadata, dict)
            else PACKAGE_NAME
        )
        if not isinstance(title, str):
            title = PACKAGE_NAME
        description = abstract_text(document)
        canonical_url = encoded_url(base_url, route)

        destination = site / route.removeprefix("/")
        destination.mkdir(parents=True, exist_ok=True)
        (destination / "index.html").write_text(
            seo_shell(template, title, description, canonical_url),
            encoding="utf-8",
        )
        routes[route] = {
            "route": route,
            "title": title,
            "description": description,
            "kind": str(document.get("kind", "symbol")),
        }
    return sorted(routes.values(), key=lambda item: item["route"])


def write_sitemap(
    site: Path,
    base_url: str,
    routes: list[dict[str, str]],
) -> None:
    today = dt.datetime.now(dt.timezone.utc).date().isoformat()
    entries = []
    for item in routes:
        if item["route"] == f"/documentation/{MODULE_NAME}":
            priority = "1.0"
        else:
            priority = "0.8" if item["kind"] == "article" else "0.6"
        url = html.escape(encoded_url(base_url, item["route"]))
        entries.append(
            f"  <url><loc>{url}</loc><lastmod>{today}</lastmod>"
            f"<priority>{priority}</priority></url>"
        )
    sitemap = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        + "\n".join(entries)
        + "\n</urlset>\n"
    )
    (site / "sitemap.xml").write_text(sitemap, encoding="utf-8")
    (site / "robots.txt").write_text(
        f"User-agent: *\nAllow: /\n\nSitemap: {base_url}/sitemap.xml\n",
        encoding="utf-8",
    )


def write_agent_resources(
    site: Path,
    base_url: str,
    version: str,
    repository: Path,
    repository_url: str,
) -> None:
    docs_url = f"{base_url}/documentation/{MODULE_NAME}/"
    llms = f"""# {PACKAGE_NAME}

> Native p5 creative coding for Swift, with Core Graphics rendering, SwiftUI integration, and a roadmap toward broad p5.js capability parity.

Current documented release: {version}

## Start here

- [Documentation overview]({docs_url})
- [SwiftUI and Swift Playgrounds]({docs_url}swiftuiandplaygrounds/)
- [P5 parity roadmap]({docs_url}p5parityroadmap/)

## API reference

- [P5Sketch]({docs_url}p5sketch/)
- [P5SketchView]({docs_url}p5sketchview/)
- [P5CanvasView]({docs_url}p5canvasview/)

## Agent resources

- [Complete documentation context]({base_url}/llms-full.txt)
- [Structured project context]({base_url}/agent-context.json)
- [DocC render data]({base_url}/data/documentation/{MODULE_NAME}.json)
- [Source repository]({repository_url})
"""
    (site / "llms.txt").write_text(llms, encoding="utf-8")

    documentation_sources = [
        "README.md",
        "Sources/P5/P5.docc/P5.md",
        "Sources/P5/P5.docc/SwiftUIAndPlaygrounds.md",
        "Sources/P5/P5.docc/P5ParityRoadmap.md",
        "Sources/P5/P5.swift",
        "Sources/P5/Core/P5Sketch.swift",
        "Sources/P5/Core/P5Operation.swift",
        "Sources/P5/SwiftUI/P5SketchView.swift",
    ]
    full_context = [
        f"# {PACKAGE_NAME}: Complete Documentation Context",
        "",
        f"Documented release: {version}",
        f"Canonical documentation: {docs_url}",
        "",
        "This file combines the authored guides and public API source for "
        "coding agents. The rendered DocC site remains the canonical human "
        "reference.",
    ]
    for relative_path in documentation_sources:
        source = repository / relative_path
        if not source.is_file():
            continue
        full_context.extend(
            [
                "",
                "---",
                "",
                f"## Source: `{relative_path}`",
                "",
                source.read_text(encoding="utf-8").rstrip(),
            ]
        )
    (site / "llms-full.txt").write_text(
        "\n".join(full_context) + "\n",
        encoding="utf-8",
    )

    context = {
        "schemaVersion": 1,
        "name": PACKAGE_NAME,
        "version": version,
        "summary": (
            "Native p5 creative coding for Swift, SwiftUI, UIKit, and AppKit."
        ),
        "canonicalDocumentation": docs_url,
        "repository": repository_url,
        "license": "MIT",
        "platforms": [
            {"name": "iOS", "minimumVersion": "17.0"},
            {"name": "macOS", "minimumVersion": "14.0"},
        ],
        "language": {"name": "Swift", "minimumVersion": "6.2", "mode": "6"},
        "packageProduct": "P5",
        "importModule": "P5",
        "recommendedIntegration": (
            "P5SketchView(size: size, makeSketch: MySketch.init(size:))"
        ),
        "importantConstraints": [
            "Sketches and their native views are main-actor isolated.",
            "A P5Sketch canvas has fixed dimensions.",
            "Browser-only objects receive native capability mappings rather than literal ports.",
            "The current release implements the 2D foundation, not the complete parity roadmap.",
        ],
        "agentResources": {
            "index": f"{base_url}/llms.txt",
            "fullContext": f"{base_url}/llms-full.txt",
            "doccData": (
                f"{base_url}/data/documentation/{MODULE_NAME}.json"
            ),
        },
    }
    (site / "agent-context.json").write_text(
        json.dumps(context, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    options = arguments()
    site = options.site.resolve()
    repository = options.repository_root.resolve()
    base_url = options.base_url.rstrip("/")
    docc_index = site / "index.html"

    if not docc_index.is_file():
        raise SystemExit(f"DocC index not found: {docc_index}")
    if not base_url.startswith("https://"):
        raise SystemExit("The canonical documentation URL must use HTTPS.")

    docc_template = docc_index.read_text(encoding="utf-8")
    fallback_path = site / "404.html"
    if (
        "<title>Documentation</title>" not in docc_template
        and fallback_path.is_file()
    ):
        docc_template = fallback_path.read_text(encoding="utf-8")
    if "<title>Documentation</title>" not in docc_template:
        raise SystemExit("The DocC HTML shell could not be identified.")

    routes = write_route_pages(site, base_url, docc_template)
    fallback_path.write_text(docc_template, encoding="utf-8")

    docs_url = f"{base_url}/documentation/{MODULE_NAME}/"
    docc_index.write_text(
        landing_shell(docc_template, docs_url),
        encoding="utf-8",
    )
    (site / ".nojekyll").touch()

    write_sitemap(site, base_url, routes)
    write_agent_resources(
        site,
        base_url,
        options.version,
        repository,
        options.repository_url,
    )


if __name__ == "__main__":
    main()
