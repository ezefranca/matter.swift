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
mkdir -p "$OUTPUT_ROOT"
for PRODUCT in P5SmokeSample MatterSmokeSample ML5SmokeSample; do
  swift build --configuration release --product "$PRODUCT"
done
BIN_PATH=$(swift build --configuration release --show-bin-path)

record() {
  local template=$1
  local sample=$2
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
    --launch -- "$BIN_PATH/$sample"
  status=$?
  set -e

  # xctrace returns 54 when a recording ends at its requested time limit even
  # though it wrote a valid trace. Reject every other failure and verify that
  # the resulting archive is readable before continuing.
  if [[ $status -ne 0 && $status -ne 54 ]]; then
    return "$status"
  fi
  xcrun xctrace export \
    --input "$OUTPUT_ROOT/$slug.trace" \
    --toc \
    --output "$table_of_contents"
  grep -Fq "template-name>$template<" "$table_of_contents"
}

record "Time Profiler" MatterSmokeSample
record "Allocations" P5SmokeSample
record "Leaks" P5SmokeSample
record "Metal System Trace" P5SmokeSample
record "Core ML" ML5SmokeSample
record "Power Profiler" MatterSmokeSample

echo "Instruments audit traces written to $OUTPUT_ROOT; inspect and summarize them locally."
