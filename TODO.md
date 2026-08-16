# Release readiness

The independent matter.swift repository has no remaining implementation work for its current pre-1.0 scope. Exhaustive *Nature of Code* example ports are explicitly excluded.

## Local definition of done

- [x] Single `Matter` library product with no production package dependency.
- [x] Complete source, tests, DocC catalog, smoke sample, shared scheme/test plan, privacy manifest, and API baseline.
- [x] 100% production line and expression-region coverage gates.
- [x] Debug/Release macOS and iOS Simulator builds and test plans.
- [x] Independent CI, documentation, SPI, dependency/security, performance, provenance, release, and post-release flows.
- [x] External-client validation and reciprocal package-family links.

## Publication handoff

- [ ] Create the public `ezefranca/matter.swift` repository and push `main`.
- [ ] Enable GitHub Pages and confirm the custom documentation route.
- [ ] Tag the reviewed semantic version and let the release workflow publish it.
- [ ] Add the public repository to Swift Package Index and confirm macOS/iOS/DocC builds.
- [ ] Record the Power Profiler pass on a physical iOS/iPadOS application target for the tagged candidate; macOS Time, Allocations, Leaks, and Metal traces pass.
