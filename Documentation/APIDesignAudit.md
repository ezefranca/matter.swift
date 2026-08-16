# 1.0 API design audit

This audit records the release-candidate review criteria for the P5, Matter, and ML5
public modules. Compiler-emitted symbol graphs are the inventory; CI rejects any
source-located public symbol without documentation and compares each module with its
checked-in API-digester baseline.

## Naming and semantics

- Names are grammatical at use sites and follow Swift API Design Guidelines. Familiar
  JavaScript terms remain only where they are the domain vocabulary (`circle`,
  `Bodies`, `classify`) and do not obscure Swift semantics.
- Initializers and mutating operations validate before committing state. Throwing
  construction is used where an invalid value cannot exist safely.
- P5 numeric geometry uses `CGFloat`, Matter simulation uses `Float` to match its Metal
  ABI, and ML5 training/archive values use `Double` with explicit float32 conversion at
  MPSGraph/Core ML boundaries.
- Persisted and public value boundaries use `Codable`, `Hashable`, and `Sendable` when
  the semantics support them. Mutable reference state is main-actor or actor owned.
- Asynchronous APIs use `async`/`await`, typed domain errors, and cooperative
  cancellation. Callback properties exist only at native event/display boundaries and
  are main-actor `@Sendable` closures.

## Ownership exceptions

Apple framework protocols such as `MTLTexture`, `CGImage`, `CVPixelBuffer`, `MLModel`,
and AVFoundation objects do not consistently declare checked `Sendable` conformance.
The small `@unchecked Sendable` wrappers are immutable values, locked synchronous
snapshots, actor-owned operation seams, or test-injection closures. Their source
comments document the invariant, and strict-concurrency, Thread Sanitizer, concurrent
caller, cancellation, and lifetime tests exercise the boundary.

P5 sketches and native media controllers are main-actor reference types because they
own views or framework graphs. Matter engines/runners and ML5 datasets/networks/caches
are actors. Geometry, world snapshots, render scenes, model configuration, trained
parameters, predictions, and events are independently retainable values.

## Availability and graceful degradation

The package declarations establish iOS 17 and macOS 14 as the availability floor.
Conditional compilation isolates AppKit/UIKit and framework-specific code. Metal,
Photos, camera, microphone, Vision/Core ML, and MPSGraph entry points expose explicit
capability, authorization, configuration, or typed failure boundaries. No library
silently changes execution backend after work begins.

## Compatibility review

The product compatibility articles name intentional JavaScript/browser differences.
The Nature of Code audit is an API-requirements reference, not a promise of bundled
example or source compatibility. An intentional public break requires migration notes,
a version decision, regenerated baselines, and the approval trailer enforced by
`Scripts/check_api_breakage.sh`.
