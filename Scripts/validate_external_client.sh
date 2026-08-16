#!/bin/bash

set -euo pipefail

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

CLIENT_ROOT=$(mktemp -d /tmp/p5-swift-client.XXXXXX)
trap 'rm -rf "$CLIENT_ROOT"' EXIT
if [[ -n "$PACKAGE_URL" ]]; then
  DEPENDENCY=".package(url: \"$PACKAGE_URL\", exact: \"$VERSION\")"
else
  RESOLVED_PATH=$(cd "$PACKAGE_PATH" && pwd)
  DEPENDENCY=".package(path: \"$RESOLVED_PATH\")"
fi

python3 - "$CLIENT_ROOT" "$DEPENDENCY" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
dependency = sys.argv[2]
(root / "Sources/P5Client").mkdir(parents=True)
(root / "Sources/MatterClient").mkdir(parents=True)
(root / "Sources/ML5Client").mkdir(parents=True)
(root / "Package.swift").write_text(f'''// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ExternalClients",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "P5Client", targets: ["P5Client"]),
        .executable(name: "MatterClient", targets: ["MatterClient"]),
        .executable(name: "ML5Client", targets: ["ML5Client"]),
    ],
    dependencies: [{dependency}],
    targets: [
        .executableTarget(name: "P5Client", dependencies: [.product(name: "P5", package: "p5.swift")]),
        .executableTarget(name: "MatterClient", dependencies: [.product(name: "Matter", package: "p5.swift")]),
        .executableTarget(name: "ML5Client", dependencies: [.product(name: "ML5", package: "p5.swift")]),
    ]
)
''', encoding="utf-8")
(root / "Sources/P5Client/main.swift").write_text('import P5\nprint(P5Vector(x: 3, y: 4).mag())\n', encoding="utf-8")
(root / "Sources/MatterClient/main.swift").write_text('import Matter\nprint(Vector(x: 3, y: 4).length)\n', encoding="utf-8")
(root / "Sources/ML5Client/main.swift").write_text('import ML5\nprint(ActivationFunction.linear.rawValue)\n', encoding="utf-8")
PY

swift build --package-path "$CLIENT_ROOT" -Xswiftc -warnings-as-errors
for CLIENT in P5Client MatterClient ML5Client; do
  swift run --package-path "$CLIENT_ROOT" --skip-build "$CLIENT"
done
echo "External SwiftPM clients resolved, built, and imported every product."
