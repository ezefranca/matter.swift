# Quality, conformance, performance, and lifetime audits

The release gate combines deterministic behavioral tests with machine-checked
line, expression-region, documentation, and API baselines. A checklist item is
not inferred merely from a type conforming to a protocol; the test suites
exercise valid values, invalid decoding, finite-number boundaries,
cancellation on both sides of asynchronous work, and actor-owned mutation.

## Serialization and compatibility

Public `Codable` state is round-tripped in the product suites. Validating custom
decoders are also given structurally valid but semantically invalid payloads so
decoding cannot bypass normal construction. Persisted envelopes in P5, Matter,
and ML5 carry explicit schema or format versions where forward interpretation
would otherwise be ambiguous. API-digester baselines independently guard source
compatibility; intentional breaks require the documented approval trailer.

## Rendering goldens and numerical conformance

P5 renderer tests compare exact RGBA bytes for deterministic Core Graphics
primitives and Metal offscreen clear/readback behavior. The same shared test
plan runs on macOS and iOS Simulator in CI. Typography and framework-dependent
antialiasing use behavioral bounds rather than brittle glyph raster hashes.

Matter's CPU reference integrator and collision ownership are compared with its
Metal integration within documented floating-point tolerances. ML5 compares
CPU dense inference and training with MPSGraph/Metal on canonical full batches.
P5's Core Graphics 2D renderer and Metal 3D renderer intentionally implement
different raster models, so a CPU-versus-GPU pixel parity claim would be
misleading; geometry, matrix ABI, and exact target readback are tested instead.

## Failure, cancellation, and isolation

Injected native seams cover Metal absence, source compilation, function and
pipeline creation, buffer/texture/depth/MSAA allocation, encoder and command
creation, failed completion, and cancellation before encoding, after encoding,
and after native completion. Core ML, MPSGraph, AVFoundation, Photos,
URLSession, persistence, and file-export tests follow the same pattern. Swift 6
language mode and the CI complete-concurrency build reject unchecked isolation
at compilation; narrowly scoped native wrappers document their
`@unchecked Sendable` rationale.

## Performance and lifetime

`Configuration/PerformanceBudgets.json` defines intentionally generous wall
clock regression ceilings for P5 Metal rendering, Matter broad-phase scaling,
and canonical ML5 training. `Scripts/run_performance_baselines.py` emits
machine-readable measurements. These are regression tripwires, not universal
device performance claims; release notes state the CI hardware and toolchain.

Long-lived P5 audio, video, capture, and Metal tests release native callbacks,
taps, sessions, and wrapper resources. Matter exposes reusable Metal-buffer
statistics and an explicit purge operation. ML5 models and inference snapshots
are immutable values, while caches have bounded inventory and explicit
eviction. Critical suites run repeatedly in CI, and Address and Thread
Sanitizer jobs cover supported macOS configurations.
