# Contributing to p5.swift

Contributions should preserve familiar p5.js behavior while using clear,
native Swift APIs.

## Before opening a pull request

1. Discuss substantial API additions in a GitHub issue.
2. Link new public APIs to their corresponding p5.js reference.
3. Document intentional platform or behavior differences.
4. Add deterministic tests for every new production code path.
5. Keep production line coverage at 100%.

## Build and test

Run the complete package suite with Xcode or standalone Command Line Tools:

```sh
swift test --parallel --enable-code-coverage
COVERAGE_JSON=$(swift test --show-codecov-path)
python3 Scripts/check_coverage.py \
  --coverage "$COVERAGE_JSON" \
  --source-root Sources/P5
python3 Scripts/check_coverage.py \
  --coverage "$COVERAGE_JSON" \
  --source-root Sources/Matter
python3 Scripts/check_coverage.py \
  --coverage "$COVERAGE_JSON" \
  --source-root Sources/ML5
```

Build the iOS variant with:

```sh
xcodebuild build \
  -scheme P5 \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Build DocC with:

```sh
xcodebuild docbuild \
  -scheme P5 \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  DOCC_HOSTING_BASE_PATH=p5.swift
```

## API design

- Follow the Swift API Design Guidelines.
- Prefer p5.js terminology when it remains clear and grammatical in Swift.
- Use `@MainActor` for UI and sketch lifecycle APIs.
- Surface invalid input explicitly.
- Avoid dependencies in the published package unless native frameworks cannot
  provide the required capability.

## Commits

Use focused Conventional Commit messages such as:

```text
feat(shape): add bezier vertices
fix(renderer): restore stroke state after pop
docs: document Swift Playgrounds integration
test: cover matrix transformations
```
