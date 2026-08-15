#!/usr/bin/env python3

"""Fail when a source-located public Swift symbol lacks a documentation comment."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from urllib.parse import unquote, urlparse


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--symbol-graph", required=True, type=Path)
    parser.add_argument("--source-root", required=True, type=Path)
    return parser.parse_args()


def source_path(uri: str) -> Path | None:
    parsed = urlparse(uri)
    if parsed.scheme != "file":
        return None
    return Path(unquote(parsed.path)).resolve()


def main() -> None:
    options = arguments()
    graph_path = options.symbol_graph.resolve()
    source_root = options.source_root.resolve()
    payload = json.loads(graph_path.read_text(encoding="utf-8"))

    public_symbols = []
    undocumented_symbols = []
    for symbol in payload["symbols"]:
        if symbol.get("accessLevel") != "public":
            continue
        location = symbol.get("location", {})
        path = source_path(location.get("uri", ""))
        if path is None or not path.is_relative_to(source_root):
            continue
        public_symbols.append(symbol)
        if "docComment" not in symbol:
            undocumented_symbols.append((symbol, path))

    if not public_symbols:
        raise SystemExit(f"No source-located public symbols found below {source_root}.")

    documented_count = len(public_symbols) - len(undocumented_symbols)
    print(
        f"{source_root.name} symbol documentation: "
        f"{documented_count}/{len(public_symbols)} (100% required)"
    )

    if undocumented_symbols:
        details = []
        for symbol, path in undocumented_symbols:
            line = symbol.get("location", {}).get("position", {}).get("line", 0) + 1
            details.append(
                f"- {path}:{line}: {symbol['names']['title']} "
                f"({symbol['kind']['displayName']})"
            )
        raise SystemExit("Undocumented public symbols:\n" + "\n".join(details))


if __name__ == "__main__":
    main()
