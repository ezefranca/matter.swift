#!/bin/bash

set -euo pipefail

REPOSITORY_ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUTPUT_ROOT=${1:-}
if [[ -z "$OUTPUT_ROOT" ]]; then
  echo "Usage: Scripts/run_instruments_audits.sh OUTPUT_DIRECTORY" >&2
  exit 64
fi
if [[ "$(xcode-select -p)" != *Xcode*.app* && "${DEVELOPER_DIR:-}" != *Xcode*.app* ]]; then
  echo "Select full Xcode or set DEVELOPER_DIR for Instruments." >&2
  exit 69
fi

cd "$REPOSITORY_ROOT"
PRODUCT=$(python3 -c 'import json; print(next(iter(json.load(open("Configuration/ModuleBoundaries.json"))["products"])))')
SAMPLE="${PRODUCT}SmokeSample"
mkdir -p "$OUTPUT_ROOT"
swift build --configuration release --product "$SAMPLE"
BIN_PATH=$(swift build --configuration release --show-bin-path)

record() {
  local template=$1
  local slug=${template// /-}
  local status
  local table_of_contents="$OUTPUT_ROOT/$slug.xml"
  set +e
  xcrun xctrace record \
    --quiet \
    --no-prompt \
    --template "$template" \
    --time-limit 15s \
    --output "$OUTPUT_ROOT/$slug.trace" \
    --target-stdout - \
    --launch -- "$BIN_PATH/$SAMPLE" </dev/null
  status=$?
  set -e
  if [[ $status -ne 0 && $status -ne 54 ]]; then
    return "$status"
  fi
  xcrun xctrace export \
    --input "$OUTPUT_ROOT/$slug.trace" \
    --toc \
    --output "$table_of_contents"
  grep -Fq "template-name>$template<" "$table_of_contents"
}

case "$PRODUCT" in
  P5)
    TEMPLATES=("Time Profiler" "Allocations" "Leaks" "Metal System Trace" "Power Profiler")
    ;;
  Matter)
    TEMPLATES=("Time Profiler" "Allocations" "Leaks" "Metal System Trace" "Power Profiler")
    ;;
  ML5)
    TEMPLATES=("Time Profiler" "Allocations" "Leaks" "Core ML" "Power Profiler")
    ;;
  *)
    echo "No Instruments policy exists for $PRODUCT." >&2
    exit 65
    ;;
esac

for TEMPLATE in "${TEMPLATES[@]}"; do
  record "$TEMPLATE"
done
echo "Instruments audit traces written to $OUTPUT_ROOT; inspect and summarize them locally."
