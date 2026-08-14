# Changelog

All notable changes to P5Swift are documented in this file.

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

[0.2.0]: https://github.com/ezefranca/P5Swift/compare/0.1.0...0.2.0
