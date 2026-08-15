#!/bin/bash

set -euo pipefail

REPOSITORY_ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD_PATH=$(swift build --package-path "$REPOSITORY_ROOT" --show-bin-path)
MODULE_PATH="$BUILD_PATH/Modules"
SDK_PATH=$(xcrun --show-sdk-path)
TARGET_TRIPLE="$(uname -m)-apple-macosx14.0"

for MODULE in P5 Matter ML5; do
  swift build \
    --package-path "$REPOSITORY_ROOT" \
    --target "$MODULE" \
    -Xswiftc -warnings-as-errors
  xcrun swift-api-digester \
    -diagnose-sdk \
    -baseline-path "$REPOSITORY_ROOT/Documentation/APIBaselines/$MODULE.json" \
    -module "$MODULE" \
    -I "$MODULE_PATH" \
    -sdk "$SDK_PATH" \
    -target "$TARGET_TRIPLE" \
    -swift-version 6 \
    -swift-only \
    -avoid-location \
    -avoid-tool-args \
    -abort-on-module-fail \
    -error-on-abi-breakage \
    -compiler-style-diags
done
