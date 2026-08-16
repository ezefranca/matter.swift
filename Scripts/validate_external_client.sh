#!/bin/bash

set -euo pipefail

REPOSITORY_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPOSITORY_ROOT"
PACKAGE_URL=""
PACKAGE_PATH=""
VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      PACKAGE_URL=${2:-}
      shift 2
      ;;
    --path)
      PACKAGE_PATH=${2:-}
      shift 2
      ;;
    --version)
      VERSION=${2:-}
      shift 2
      ;;
    *)
      echo "Usage: Scripts/validate_external_client.sh (--url URL --version X.Y.Z | --path PATH)" >&2
      exit 64
      ;;
  esac
done
if [[ -n "$PACKAGE_URL" && -n "$PACKAGE_PATH" ]] || [[ -z "$PACKAGE_URL" && -z "$PACKAGE_PATH" ]]; then
  echo "Choose exactly one package source." >&2
  exit 64
fi
if [[ -n "$PACKAGE_URL" && ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Remote validation requires a semantic version." >&2
  exit 64
fi

CLIENT_ROOT=$(mktemp -d /tmp/swift-package-client.XXXXXX)
trap 'rm -rf "$CLIENT_ROOT"' EXIT
PRODUCT=$(python3 -c 'import json; print(next(iter(json.load(open("Configuration/ModuleBoundaries.json"))["products"])))')
PACKAGE_NAME=$(basename "$REPOSITORY_ROOT")
if [[ -n "$PACKAGE_URL" ]]; then
  DEPENDENCY=".package(url: \"$PACKAGE_URL\", exact: \"$VERSION\")"
else
  RESOLVED_PATH=$(cd "$PACKAGE_PATH" && pwd)
  DEPENDENCY=".package(path: \"$RESOLVED_PATH\")"
fi

python3 - "$CLIENT_ROOT" "$DEPENDENCY" "$PRODUCT" "$PACKAGE_NAME" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
dependency, product, package_name = sys.argv[2:]
target = f"{product}ExternalClient"
(root / "Sources" / target).mkdir(parents=True)
(root / "Package.swift").write_text(f'''// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ExternalClient",
    platforms: [.macOS(.v14)],
    dependencies: [{dependency}],
    targets: [
        .executableTarget(
            name: "{target}",
            dependencies: [.product(name: "{product}", package: "{package_name}")]
        )
    ]
)
''', encoding="utf-8")
(root / "Sources" / target / "main.swift").write_text(
    f'import {product}\nprint("Imported {product} from an external SwiftPM client.")\n',
    encoding="utf-8",
)
PY

swift build --package-path "$CLIENT_ROOT" -Xswiftc -warnings-as-errors
swift run --package-path "$CLIENT_ROOT" --skip-build "${PRODUCT}ExternalClient"
echo "External SwiftPM client resolved, built, and imported $PRODUCT."
