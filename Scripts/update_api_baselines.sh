#!/bin/bash

set -euo pipefail

REPOSITORY_ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD_PATH=$(swift build --package-path "$REPOSITORY_ROOT" --show-bin-path)
MODULE_PATH="$BUILD_PATH/Modules"
SDK_PATH=$(xcrun --show-sdk-path)
TARGET_TRIPLE="$(uname -m)-apple-macosx14.0"
BASELINE_PATH="$REPOSITORY_ROOT/Documentation/APIBaselines"
mkdir -p "$BASELINE_PATH"

for MODULE in P5 Matter ML5; do
  swift build \
    --package-path "$REPOSITORY_ROOT" \
    --target "$MODULE" \
    -Xswiftc -warnings-as-errors
  xcrun swift-api-digester \
    -dump-sdk \
    -module "$MODULE" \
    -I "$MODULE_PATH" \
    -sdk "$SDK_PATH" \
    -target "$TARGET_TRIPLE" \
    -swift-version 6 \
    -swift-only \
    -avoid-location \
    -avoid-tool-args \
    -o "$BASELINE_PATH/$MODULE.json"
done

echo "Updated P5, Matter, and ML5 API baselines."
