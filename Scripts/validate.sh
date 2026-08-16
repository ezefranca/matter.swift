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
TARGETS=$(python3 -c 'import json; print(*json.load(open("Configuration/ModuleBoundaries.json"))["products"])')
VALIDATION_TEMP=$(mktemp -d /tmp/p5-swift-validation.XXXXXX)
trap 'rm -rf "$VALIDATION_TEMP"' EXIT

python3 Scripts/check_support_policy.py
python3 Scripts/check_privacy_manifests.py
python3 Scripts/check_repository_hygiene.py
python3 Scripts/check_dependency_policy.py
python3 Scripts/check_workflow_security.py
python3 Scripts/check_package_family.py
python3 Scripts/check_links.py
python3 -m unittest discover -s Tests/ScriptTests -v
FORMAT_PATHS=(Package.swift Sources Tests)
if [[ -d P5Demo/P5Demo ]]; then
  FORMAT_PATHS+=(P5Demo/P5Demo)
fi
swift format lint \
  --configuration .swift-format \
  --recursive \
  --parallel \
  --strict \
  "${FORMAT_PATHS[@]}"

swift build --configuration release -Xswiftc -warnings-as-errors
swift test --parallel --enable-code-coverage -Xswiftc -warnings-as-errors

COVERAGE_JSON=$(swift test --show-codecov-path)
for TARGET in $TARGETS; do
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
  ACTIVE_DEVELOPER_DIR=${DEVELOPER_DIR:-$(xcode-select -p)}
  if [[ "$ACTIVE_DEVELOPER_DIR" != *Xcode*.app/Contents/Developer ]]; then
    echo "Full Xcode is required; use --skip-xcode only when Xcode jobs run separately." >&2
    exit 69
  fi
  export DEVELOPER_DIR="$ACTIVE_DEVELOPER_DIR"
  xcodebuild -version
  IOS_SIMULATOR_ID=$(
    xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
print(next(
    device["udid"]
    for runtime in devices.values()
    for device in runtime
    if "iPhone" in device["name"]
))
'
  )
  mkdir -p "$VALIDATION_TEMP/results"
  for TARGET in $TARGETS; do
    for PLATFORM in macOS "iOS Simulator"; do
      for CONFIGURATION in Debug Release; do
        xcodebuild build \
          -scheme "$TARGET" \
          -configuration "$CONFIGURATION" \
          -destination "generic/platform=$PLATFORM" \
          -derivedDataPath "$VALIDATION_TEMP/xcode/$TARGET-$PLATFORM-$CONFIGURATION" \
          CODE_SIGNING_ALLOWED=NO \
          SWIFT_SUPPRESS_WARNINGS=NO \
          SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
      done
    done
    xcodebuild docbuild \
      -scheme "$TARGET" \
      -destination 'generic/platform=macOS' \
      -derivedDataPath "$VALIDATION_TEMP/docc/$TARGET" \
      CODE_SIGNING_ALLOWED=NO \
      SWIFT_SUPPRESS_WARNINGS=NO \
        SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
        DOCC_WARNINGS_AS_ERRORS=YES
    for DESTINATION in 'platform=macOS' "id=$IOS_SIMULATOR_ID"; do
      PLATFORM_NAME=$(printf '%s' "$DESTINATION" | tr '=, ' '---')
      xcodebuild test \
        -quiet \
        -skipMacroValidation \
        -scheme "$TARGET" \
        -testPlan "$TARGET" \
        -destination "$DESTINATION" \
        -derivedDataPath "$VALIDATION_TEMP/tests/$TARGET-$PLATFORM_NAME" \
        -resultBundlePath "$VALIDATION_TEMP/results/$TARGET-$PLATFORM_NAME.xcresult" \
        CODE_SIGNING_ALLOWED=NO \
        SWIFT_SUPPRESS_WARNINGS=NO \
        SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
    done
  done
  if [[ -f P5Demo/P5Demo.xcodeproj/project.pbxproj ]]; then
    for CONFIGURATION in Debug Release; do
      xcodebuild build \
        -project P5Demo/P5Demo.xcodeproj \
        -scheme P5Demo \
        -configuration "$CONFIGURATION" \
        -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath "$VALIDATION_TEMP/xcode/P5Demo-$CONFIGURATION" \
        CODE_SIGNING_ALLOWED=NO \
        SWIFT_SUPPRESS_WARNINGS=NO \
        SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
    done
  fi
fi

echo "$(basename "$REPOSITORY_ROOT") validation passed."
