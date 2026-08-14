# p5.swift Changelog

All notable changes to p5.swift are documented in this file.

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
