# Contributing

Thank you for improving this package. Changes should feel native to Swift and Apple platforms, preserve deterministic behavior, and keep the repository independently releasable.

## Before opening a change

- Use Swift 6.2.3 or newer in the tested range, Xcode 26, macOS 14+, and iOS 17+.
- Open an issue before a broad public-API redesign, dependency addition, backend-policy change, or compatibility promise.
- Keep production targets dependency-free unless a reviewed ADR and license/security audit justify otherwise.
- Never commit credentials, downloaded models, generated Xcode user state, result bundles, traces, or build products.

## Implementation expectations

- Follow the Swift API Design Guidelines and the actor/value ownership documented in `Documentation/APIDesignAudit.md`.
- Validate public inputs before mutation and preserve typed domain errors and cooperative cancellation.
- Document every public symbol with DocC, including ownership, thread/actor semantics, validation, failure behavior, and intentional JavaScript/native differences where relevant.
- Add deterministic Swift Testing coverage for success, invalid/boundary values, serialization, cancellation, resource lifetime, and injected native failures.
- Update the compatibility guide, migration notes, API baseline, benchmark policy, privacy manifest, and third-party notices whenever a change affects them.
- Keep Metal source warning-free for both macOS and iOS Simulator SDKs. Do not hide a backend change behind silent fallback.
- Model fixtures must be repository-authored or redistributable and must record license, provenance, ownership, and integrity information.

## Required checks

```sh
swift format --configuration .swift-format --recursive --in-place Package.swift Sources Tests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash Scripts/validate.sh
python3 Scripts/run_performance_baselines.py --skip-build
bash Scripts/validate_external_client.sh --path .
```

Instruments traces are local diagnostics; summarize findings in release notes and never commit trace archives.

## Public API changes

`swift-api-digester` compares the module with `Documentation/APIBaselines`. An intentional break requires maintainer approval, a semantic-version decision, migration guidance, changelog entry, and then an explicit baseline update with `Scripts/update_api_baselines.sh`. Never regenerate a baseline merely to make CI green.

## Pull requests

Describe the user-visible result, native/compatibility tradeoffs, tests, platform evidence, performance impact, and documentation changes. CI must remain warning-free and preserve 100% production line and expression-region coverage.
