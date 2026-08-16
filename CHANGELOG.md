# p5.swift Changelog

All notable changes to p5.swift are documented in this file.

## [Unreleased]

### Added

- `Matter`, a native Swift, Metal-first conceptual port of Matter.js,
  including `Vector`, `Body`, `World`, Matter-style body factories, an
  actor-owned Metal `Engine`, a bundled integration kernel, and a
  deterministic CPU `ReferenceIntegrator`.
- Deterministic Matter tests cover validation, Codable state, cancellation,
  and every typed Metal resource or command failure, with a 100% line-coverage
  gate.
- `ML5`, native Swift foundations for on-device machine learning inspired by
  ml5.js, including an actor-isolated `NeuralNetwork`, typed
  classification/regression tasks, `FeatureVector`, and a Core ML backed
  `ModelPredicting` implementation.
- Comprehensive ML5 validation, task, cancellation, Core ML conversion, and
  compiled-model integration tests, with a 100% production line-coverage gate.
- This repository now ships all three packages (`P5`, `Matter`, `ML5`) as
  separate SwiftPM library products from one `Package.swift`.
- `P5Vector`, including p5-style vector arithmetic and direction APIs, Swift
  operators, deterministic random-vector construction, Core Graphics bridges,
  and `P5Sketch.createVector()`.
- Complete DocC comments for all source-located public symbols in P5, Matter,
  and ML5, enforced from compiler-emitted symbol graphs in CI.
- Compiler-generated public API baselines for all three products, plus CI
  breakage diagnostics and an explicit review path for intentional changes.
- Native P5 video metadata, exact or tolerant frame extraction, and an
  AVPlayer-backed main-actor playback controller with looping, scene lifecycle,
  cancellation, and typed transport failures.
- A native AVAudioEngine graph for file playback and periodic oscillators,
  deterministic ADSR envelopes, and thread-safe RMS/FFT output analysis backed
  by Accelerate.
- Cancellation-aware local and URLSession data loading, typed text and JSON
  decoding, and validated CSV/TSV/semicolon/pipe tables with quoted-field and
  multiline-record support.

## [0.3.2] - 2026-08-14

### Fixed

- Exclude the macOS-only test target from normal iOS scheme builds.
- Build and upload DocC even before GitHub Pages is enabled.
- Restore canonical links after the GitHub repository rename.

## [0.3.1] - 2026-08-14

### Fixed

- Rename the shared Xcode package scheme to `P5` for iOS and DocC builds.
- Enable GitHub Pages automatically from the documentation workflow.
- Use working repository URLs before the GitHub repository rename.

## [0.3.0] - 2026-08-14

### Added

- `P5SketchView`, a lifecycle-safe SwiftUI wrapper for iOS and macOS.
- Swift Playgrounds App and Xcode playground documentation.
- Automatic sketch recreation when a SwiftUI canvas changes size.
- GitHub Pages deployment for the DocC documentation.
- Search-engine route pages, sitemap, robots policy, and canonical metadata.
- Agent-readable `llms.txt`, complete context, and structured package metadata.
- A roadmap toward near-complete native p5.js capability parity.
- The `p5.swift` package name and `P5` importable module.
- Automated semantic-version publishing through GitHub Releases.
- Platform, language, test, documentation, and release badges.
- Twenty deterministic Swift Testing tests with a 100% line-coverage gate.
- MIT licensing, contribution guidelines, and a security policy.

### Attribution

- This project is an expanded fork of
  [Juan Hurtado's P5Swift](https://github.com/juandahurt/P5Swift).

## [0.2.0] - 2026-08-14

### Added

- Swift 6.2 package support for iOS 17 and macOS 14.
- Native macOS canvas support.
- `ellipse(_:_:)`, `noStroke()`, and `strokeWeight(_:)`.
- DocC API documentation linked to the corresponding p5.js reference.
- GitHub Actions package testing.

### Changed

- `circle()` now accepts a diameter, matching p5.js.
- Drawing state is isolated per sketch and `push()` / `pop()` preserve styles.
- The draw loop uses native display scheduling.
- The preferred initializer is now `init(size:)`.
- Default drawing styles now match p5.js: white fill and black stroke.

### Deprecated

- `init(ofSize:)` in favor of `init(size:)`.

[0.3.2]: https://github.com/ezefranca/p5.swift/compare/0.3.1...0.3.2
[0.3.1]: https://github.com/ezefranca/p5.swift/compare/0.3.0...0.3.1
[0.3.0]: https://github.com/ezefranca/p5.swift/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/ezefranca/p5.swift/compare/0.1.0...0.2.0
