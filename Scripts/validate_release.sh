#!/bin/bash

set -euo pipefail

REPOSITORY_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TAG=""
SKIP_XCODE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG=${2:-}
      shift 2
      ;;
    --skip-xcode)
      SKIP_XCODE=true
      shift
      ;;
    *)
      echo "Usage: Scripts/validate_release.sh [--tag X.Y.Z] [--skip-xcode]" >&2
      exit 64
      ;;
  esac
done

cd "$REPOSITORY_ROOT"
PRODUCT=$(python3 -c 'import json; print(next(iter(json.load(open("Configuration/ModuleBoundaries.json"))["products"])))')
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Release validation requires a clean worktree." >&2
  exit 65
fi
if [[ -z "$TAG" ]]; then
  TAG=$(git describe --tags --exact-match 2>/dev/null || true)
fi
if [[ ! "$TAG" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Release tag must use X.Y.Z semantic version syntax." >&2
  exit 64
fi
git rev-parse --verify "refs/tags/$TAG" >/dev/null
if ! rg -q "^## \[$TAG\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" CHANGELOG.md; then
  echo "CHANGELOG.md has no dated section for $TAG." >&2
  exit 65
fi

if [[ "$SKIP_XCODE" == true ]]; then
  bash Scripts/validate.sh --skip-xcode
else
  bash Scripts/validate.sh
fi
bash Scripts/check_api_breakage.sh
python3 Scripts/check_dependency_policy.py
python3 Scripts/check_links.py
swift build --product "${PRODUCT}SmokeSample" -Xswiftc -warnings-as-errors
echo "Release candidate $TAG passed all local gates."
