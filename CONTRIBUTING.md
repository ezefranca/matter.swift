# Contributing

Thank you for improving P5, Matter, or ML5. The projects preserve familiar
creative-coding concepts while using clear, safe Apple-platform APIs.

## Choose the right boundary

- P5 owns sketch lifecycle, rendering, input, media, data, persistence, and native UI.
- Matter owns deterministic physics values, solvers, runners, and drawing snapshots.
- ML5 owns typed model data, training, inference, model persistence, and Vision/Core ML.
- Production targets never depend on one another. Cross-product orchestration belongs
  in a sample or application target.

Discuss a substantial API or serialized-format change in an issue first. Link the
authoritative p5.js, Matter.js, ml5.js, Apple, or research reference and describe the
native behavior before implementation.

## Required quality

Every change must:

1. follow Swift API Design Guidelines and the checked-in format policy;
2. preserve value semantics and `Sendable` boundaries where possible;
3. isolate mutable shared or native state with an actor or documented main-actor rule;
4. validate nonfinite values, sizes, indices, state transitions, and decoded archives;
5. use typed errors, structured concurrency, and cooperative cancellation;
6. document ownership, thread safety, availability, failures, and native differences;
7. add deterministic valid, invalid, boundary, serialization, and cancellation tests;
8. retain 100% production line and expression-region coverage;
9. update compatibility, performance, API baseline, privacy, and changelog artifacts
   when affected.

Never add a silent GPU/CPU fallback. Make the execution policy and the point at which
fallback may occur explicit. Do not commit third-party models without license,
provenance, ownership, and integrity metadata.

## Local validation

Run the same release-quality entry point used in CI:

```sh
bash Scripts/validate.sh
```

Command Line Tools without full Xcode can run:

```sh
bash Scripts/validate.sh --skip-xcode
```

That is only the SwiftPM half of the gate; CI must still pass the macOS/iOS scheme,
test-plan, Metal, sanitizer, documentation, and toolchain matrix jobs. To inspect
performance and independent consumer integration:

```sh
python3 Scripts/run_performance_baselines.py
bash Scripts/validate_external_client.sh --path .
```

## Specialized changes

### Public APIs and serialized formats

Add tests through the public import boundary. Regenerate the relevant API baseline
with the command in `Documentation/APIBaselines/README.md`. Intentional source breaks
require the documented approval trailer and migration notes. Version persisted
envelopes before making incompatible decoding changes.

### Metal

Keep Swift and Metal buffer layouts synchronized, validate all resource creation, and
test injected compilation, allocation, encoding, completion, and cancellation paths.
Run the same shader against macOS and iOS SDKs. Record ownership for every
`@unchecked Sendable` wrapper.

### Machine-learning models

Include a model card, license, source URL, SHA-256 digest, intended use, limitations,
input/output schema, and evaluation data. Tests must be deterministic and must not
download resources. Treat privacy, bias, memory, thermal cost, and compute-device
selection as product behavior.

### Documentation and samples

Use compile-valid snippets, typed error handling, accessible UI labels, and explicit
platform assumptions. Update local links and upstream compatibility references.
Focused samples should teach one behavior and import only their intended product;
exhaustive Nature of Code example ports are outside this repository's scope.

### Performance

Use deterministic workloads and algorithmic assertions before adding a wall-clock
budget. Record device, architecture, OS, Swift/Xcode version, seed, workload, and
measurement command. Do not commit Instruments traces or generated build products.

## Pull requests

Keep changes focused and explain behavior, tests, compatibility impact, and measured
performance. Use clear commit subjects such as `Add collision warm starting` or
`Document Metal resource ownership`. Before requesting review, verify a clean diff,
run validation, and confirm that generated user state and credentials are absent.

Security reports belong in GitHub private vulnerability reporting, not a public issue.
By contributing, you agree that your contribution is licensed under this repository's
MIT License and that you have the right to submit it.
