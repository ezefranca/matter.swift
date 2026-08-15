#!/bin/bash

set -euo pipefail

REPOSITORY_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SKIP_XCODE=false
if [[ "${1:-}" == "--skip-xcode" ]]; then
  SKIP_XCODE=true
elif [[ $# -ne 0 ]]; then
  echo "Usage: Scripts/validate.sh [--skip-xcode]" >&2
  exit 64
fi

cd "$REPOSITORY_ROOT"
VALIDATION_TEMP=$(mktemp -d /tmp/p5-swift-validation.XXXXXX)
trap 'rm -rf "$VALIDATION_TEMP"' EXIT

python3 Scripts/check_support_policy.py
python3 -m unittest discover -s Tests/ScriptTests -v
swift format lint \
  --configuration .swift-format \
  --recursive \
  --parallel \
  --strict \
  Package.swift Sources Tests

swift build --configuration release -Xswiftc -warnings-as-errors
swift test --parallel --enable-code-coverage -Xswiftc -warnings-as-errors

COVERAGE_JSON=$(swift test --show-codecov-path)
for TARGET in P5 Matter ML5; do
  python3 Scripts/check_coverage.py \
    --coverage "$COVERAGE_JSON" \
    --source-root "Sources/$TARGET"

  SYMBOL_GRAPH_PATH="$VALIDATION_TEMP/symbol-graphs/$TARGET"
  mkdir -p "$SYMBOL_GRAPH_PATH"
  swift build \
    --target "$TARGET" \
    -Xswiftc -warnings-as-errors \
    -Xswiftc -emit-symbol-graph \
    -Xswiftc -emit-symbol-graph-dir \
    -Xswiftc "$SYMBOL_GRAPH_PATH"
  python3 Scripts/check_symbol_documentation.py \
    --symbol-graph "$SYMBOL_GRAPH_PATH/$TARGET.symbols.json" \
    --source-root "Sources/$TARGET"
done

bash Scripts/check_api_breakage.sh

if [[ "$SKIP_XCODE" == false ]]; then
  if [[ "$(xcode-select -p)" != *Xcode.app* ]]; then
    echo "Full Xcode is required; use --skip-xcode only when Xcode jobs run separately." >&2
    exit 69
  fi
  for TARGET in P5 Matter ML5; do
    for PLATFORM in macOS "iOS Simulator"; do
      for CONFIGURATION in Debug Release; do
        xcodebuild build \
          -scheme "$TARGET" \
          -configuration "$CONFIGURATION" \
          -destination "generic/platform=$PLATFORM" \
          -derivedDataPath "$VALIDATION_TEMP/xcode/$TARGET-$PLATFORM-$CONFIGURATION" \
          CODE_SIGNING_ALLOWED=NO \
          SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
      done
    done
    xcodebuild docbuild \
      -scheme "$TARGET" \
      -destination 'generic/platform=macOS' \
      -derivedDataPath "$VALIDATION_TEMP/docc/$TARGET" \
      CODE_SIGNING_ALLOWED=NO \
      SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
      DOCC_WARNINGS_AS_ERRORS=YES
  done
fi

echo "p5.swift validation passed."
