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
MODULES = (
    {
        "name": "P5",
        "slug": "p5",
        "summary": "Native creative coding with Core Graphics and SwiftUI.",
    },
    {
        "name": "Matter",
        "slug": "matter",
        "summary": "Deterministic, Metal-first native physics.",
    },
    {
        "name": "ML5",
        "slug": "ml5",
        "summary": "Typed on-device machine learning with Core ML.",
    },
)


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
        return "Native creative coding, physics, and machine learning for Swift."
    text = "".join(
        fragment.get("text", "")
        for fragment in fragments
        if isinstance(fragment, dict) and isinstance(fragment.get("text"), str)
    )
    return text or "Native creative coding, physics, and machine learning for Swift."


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


def landing_page(base_url: str, version: str) -> str:
    cards = []
    for module in MODULES:
        route = f"{base_url}/documentation/{module['slug']}/"
        cards.append(
            '<a class="card" href="'
            + html.escape(route, quote=True)
            + '"><span class="eyebrow">Swift package product</span><h2>'
            + html.escape(module["name"])
            + "</h2><p>"
            + html.escape(module["summary"])
            + "</p><span class=\"link\">Open documentation →</span></a>"
        )
    safe_base_url = html.escape(base_url, quote=True)
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{PACKAGE_NAME} Documentation</title>
<meta name="description" content="Native Swift creative coding, physics, and on-device machine learning for Apple platforms.">
<link rel="canonical" href="{safe_base_url}/">
<link rel="alternate" type="text/plain" href="{safe_base_url}/llms.txt" title="Documentation for language models">
<meta property="og:type" content="website"><meta property="og:title" content="{PACKAGE_NAME} Documentation">
<meta property="og:description" content="Three independent Swift products for creative coding, native physics, and machine learning.">
<style>
:root{{color-scheme:light dark;font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif;background:#f5f5f7;color:#1d1d1f}}
*{{box-sizing:border-box}}body{{margin:0}}main{{max-width:1080px;margin:auto;padding:clamp(3rem,9vw,8rem) 1.5rem}}
.eyebrow{{font-size:.78rem;font-weight:650;letter-spacing:.04em;text-transform:uppercase;color:#6e6e73}}
h1{{font-size:clamp(2.8rem,8vw,6rem);letter-spacing:-.055em;line-height:.95;margin:.35rem 0 1.4rem;max-width:850px}}
.intro{{font-size:clamp(1.15rem,2.4vw,1.6rem);line-height:1.45;color:#6e6e73;max-width:760px}}
.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:1rem;margin-top:3.5rem}}
.card{{display:block;min-height:250px;padding:1.6rem;border-radius:24px;background:#fff;color:inherit;text-decoration:none;box-shadow:0 4px 28px #0000000a;transition:transform .2s,box-shadow .2s}}
.card:hover{{transform:translateY(-3px);box-shadow:0 12px 36px #00000018}}h2{{font-size:2rem;margin:.55rem 0}}p{{line-height:1.5;color:#6e6e73}}.link{{display:block;margin-top:2.2rem;color:#06c;font-weight:600}}
footer{{margin-top:3rem;color:#6e6e73;font-size:.9rem}}footer a{{color:inherit}}
@media(prefers-color-scheme:dark){{:root{{background:#000;color:#f5f5f7}}.card{{background:#1d1d1f}}.eyebrow,.intro,p,footer{{color:#a1a1a6}}.link{{color:#2997ff}}}}
@media(prefers-reduced-motion:reduce){{.card{{transition:none}}}}
</style></head><body><main><span class="eyebrow">Version {html.escape(version)}</span>
<h1>Creative computation, native to Swift.</h1>
<p class="intro">One package, three independently importable libraries for Apple platforms. Explore the API reference, architecture, and migration guidance for each product.</p>
<section class="grid" aria-label="Package products">{''.join(cards)}</section>
<footer><a href="llms.txt">Agent-readable index</a> · <a href="llms-full.txt">Complete context</a> · <a href="agent-context.json">Structured metadata</a></footer>
</main></body></html>"""


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
        if item["route"] in {
            f"/documentation/{module['slug']}" for module in MODULES
        }:
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
    documentation_links = "\n".join(
        f"- [{module['name']} documentation]({base_url}/documentation/{module['slug']}/): {module['summary']}"
        for module in MODULES
    )
    llms = f"""# {PACKAGE_NAME}

> Three independently importable native Swift libraries for creative coding, Metal-first physics, and approachable on-device machine learning.

Current documented release: {version}

## Products

{documentation_links}

## Agent resources

- [Complete documentation context]({base_url}/llms-full.txt)
- [Structured project context]({base_url}/agent-context.json)
- [P5 DocC render data]({base_url}/data/documentation/p5.json)
- [Matter DocC render data]({base_url}/data/documentation/matter.json)
- [ML5 DocC render data]({base_url}/data/documentation/ml5.json)
- [Source repository]({repository_url})
"""
    (site / "llms.txt").write_text(llms, encoding="utf-8")

    documentation_sources = ["README.md", "TODO.md"]
    for product in ("P5", "Matter", "ML5"):
        source_root = repository / "Sources" / product
        documentation_sources.extend(
            str(path.relative_to(repository))
            for path in sorted(source_root.rglob("*"))
            if path.suffix in {".swift", ".md", ".metal"}
        )
    full_context = [
        f"# {PACKAGE_NAME}: Complete Documentation Context",
        "",
        f"Documented release: {version}",
        f"Canonical documentation: {base_url}/",
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
        "schemaVersion": 2,
        "name": PACKAGE_NAME,
        "version": version,
        "summary": "Native Swift creative coding, physics, and machine learning.",
        "canonicalDocumentation": f"{base_url}/",
        "repository": repository_url,
        "license": "MIT",
        "platforms": [
            {"name": "iOS", "minimumVersion": "17.0"},
            {"name": "macOS", "minimumVersion": "14.0"},
        ],
        "language": {"name": "Swift", "minimumVersion": "6.2", "mode": "6"},
        "products": [
            {
                "name": module["name"],
                "importModule": module["name"],
                "documentation": f"{base_url}/documentation/{module['slug']}/",
                "summary": module["summary"],
            }
            for module in MODULES
        ],
        "importantConstraints": [
            "P5 sketches and their native views are main-actor isolated.",
            "Matter Engine and ML5 NeuralNetwork serialize mutable backend access with actors.",
            "Browser-only objects receive native capability mappings rather than literal ports.",
            "The package products share a semantic version but do not depend on one another.",
        ],
        "agentResources": {
            "index": f"{base_url}/llms.txt",
            "fullContext": f"{base_url}/llms-full.txt",
            "doccData": {
                module["name"]: f"{base_url}/data/documentation/{module['slug']}.json"
                for module in MODULES
            },
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

    docc_index.write_text(
        landing_page(base_url, options.version),
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
