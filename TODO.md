# Completion plan

This is the execution checklist for taking p5.swift from its current WIP state
to a production-quality Apple-platform release. An item is complete only when
its implementation, tests, public documentation, and supported-platform builds
all pass. Checked boxes must point to durable evidence in the repository or CI.

The compatibility audit is pinned to
[`nature-of-code/noc-book-2`](https://github.com/nature-of-code/noc-book-2)
commit `03b9a7eea3b56be8dfaef324736cf56455a2c5e4` (344 JavaScript source
files across the official examples). Re-audit upstream before every minor
release.

## Definition of done

- [x] `import P5`, `import Matter`, and `import ML5` are independently usable;
  none of the three library targets depends on either of the others.
- [x] Decide and document the distribution topology before 1.0: three separately
  versioned repositories, superseding the initial staging-monorepo decision.
- [ ] Every supported public symbol has a complete DocC comment, availability,
  thread-safety semantics, validation behavior, and a native-difference note
  where JavaScript behavior cannot map literally.
- [ ] Every public behavior has deterministic unit coverage; each production
  target maintains 100% line coverage and meaningful branch coverage.
- [ ] Every product builds in Debug and Release for supported macOS and iOS
  destinations with warnings treated as errors.
- [ ] Swift Package Index builds all three products and documentation catalogs.
- [ ] GitHub Pages publishes versioned, searchable documentation for all three
  products plus complete `llms.txt` and symbol metadata.
- [ ] The pinned Nature of Code audit is used as an API-requirements reference;
  exhaustive example manifests and ports are explicitly outside release scope.
- [ ] Accessibility, cancellation, resource lifetime, memory behavior, GPU/CPU
  failure behavior, and privacy requirements are documented and tested.
- [ ] A clean checkout passes the documented build, test, documentation, example,
  and release-validation commands without private machine state.
- [ ] The 1.0 API has completed Swift API Design Guidelines review, API-diff
  review, license/attribution review, and release-candidate validation.

## 0. Baseline and repository architecture

- [x] One SwiftPM manifest exposes `P5`, `Matter`, and `ML5` library products.
- [x] Each product has its own source target, test target, and DocC catalog.
- [x] The three production targets have no dependencies on one another.
- [x] Record ADR 0002 for separate release repositories, including ownership,
  versioning, infrastructure, cross-links, and migration requirements.
- [x] Define supported Swift, Xcode, macOS, iOS, simulator, and Metal feature-set
  policy in one machine-readable source of truth.
- [x] Add ownership boundaries and dependency rules that CI can validate.
- [x] Add a public API baseline for each product using `swift-api-digester`.
- [x] Add an API-breakage job and an intentional-breaking-change approval path.
- [x] Add repository-wide formatting and lint configuration pinned to the tested
  Swift toolchain.
- [x] Treat compiler warnings, documentation warnings, and lint violations as CI
  failures.
- [ ] Remove committed Xcode-generated state that is not required for consumers,
  and document which generated files are intentionally versioned.
- [ ] Audit product/module names for collisions with Apple frameworks and document
  the naming decision.
- [x] Make all package test commands work without optional environment
  variables or undeclared toolchain modules.
- [x] Add `Scripts/validate.sh` as the single local/CI release-quality entry point.

## 1. Testing and quality gates

- [x] Swift Testing suites exist for P5, Matter, and ML5.
- [x] P5 production line coverage is 100% on the current branch.
- [x] Raise Matter production line coverage from the audited 82.49% to 100%.
- [x] Raise ML5 production line coverage from the audited 42.69% to 100%.
- [x] Enforce independent P5, Matter, and ML5 coverage ratchets in CI.
- [x] Add expression-region coverage reporting as Swift/LLVM's branch proxy;
  generated accessors and inactive conditional-compilation branches are excluded
  by LLVM's source coverage map.
- [x] Add public-client tests that import each product without `@testable`.
- [ ] Add serialization round-trip and forward/backward compatibility tests for
  every public `Codable` model.
- [ ] Add invalid-input, boundary-value, floating-point, cancellation, and actor
  isolation tests for every public API.
- [x] Add deterministic seeded tests for the current randomized and noisy
  algorithms, including a fixed SplitMix64 golden sequence and repeatable Perlin
  fields.
- [ ] Add macOS and iOS snapshot/golden-image tests for rendering behavior.
- [ ] Add CPU-versus-GPU numerical conformance tests with documented tolerances.
- [ ] Add Metal-unavailable, shader-compilation, allocation, encoder, command
  buffer, cancellation, and device-loss failure tests.
- [ ] Add performance baselines for rendering, physics step throughput, collision
  scaling, neural inference, and neural training.
- [ ] Add memory-growth and resource-lifetime tests for long-running sketches.
- [ ] Run sanitizer jobs where supported: Address, Thread, and Undefined Behavior.
- [ ] Add strict-concurrency builds for all products and examples.
- [ ] Add flaky-test detection and repeat critical deterministic suites in CI.

## 2. CI, release, and Swift Package Index

- [x] Basic test, documentation, and release workflows exist.
- [x] `.spi.yml` lists P5, Matter, and ML5 documentation targets for macOS.
- [x] Create shared Xcode schemes for P5, Matter, and ML5.
- [ ] Create test plans that include each product suite and integration suites.
- [x] Build each product independently for macOS Debug and Release in CI.
- [x] Build each product independently for iOS Simulator Debug and Release in CI.
- [ ] Run package tests through the supported standalone Swift toolchain and Xcode.
- [ ] Validate the bundled Metal source on every supported SDK and architecture.
- [ ] Add a CI matrix for the minimum supported and current stable toolchains.
- [ ] Cache dependencies and build products without hiding clean-build failures.
- [ ] Add dependency review, secret scanning, and license-policy validation.
- [x] Build all three DocC archives with warnings treated as errors.
- [x] Publish P5, Matter, and ML5 documentation under stable independent routes.
- [x] Generate a documentation landing page that clearly presents all products.
- [x] Generate version metadata, sitemap, canonical URLs, and `llms.txt` content
  from all three symbol graphs and DocC catalogs.
- [ ] Verify the production SPI build after every release and expose status badges
  for every supported platform/product combination.
- [ ] Validate semantic version tags, changelog entries, clean worktrees, tests,
  documentation, examples, and API diffs before creating a release.
- [ ] Produce checksummed release provenance and a machine-readable release manifest.
- [ ] Add a rollback/yank procedure and post-release smoke test.

## 3. Documentation and developer experience

- [x] P5 has a DocC landing page, parity roadmap, and SwiftUI/Playgrounds guide.
- [x] Matter and ML5 have initial DocC landing and architecture pages.
- [x] Document the remaining P5 public symbols, including operator semantics.
- [x] Document every Matter public symbol; current symbol graph is 84/84 documented.
- [x] Document every ML5 public symbol; current symbol graph is 114/114 documented.
- [ ] Add executable usage snippets for every major feature and error path.
- [ ] Add tutorials for first P5 sketch, first Matter world, and first ML5 model.
- [x] Add a conceptual article for P5 monotonic timing and deterministic manual frames.
- [ ] Add conceptual articles for coordinates, color, concurrency, Metal execution,
  Core ML, MPSGraph training, and resource ownership.
- [ ] Publish explicit p5.js, Matter.js, and ml5.js compatibility tables.
- [ ] Link each compatibility API to its authoritative upstream reference.
- [ ] Document all intentional differences from JavaScript and browser behavior.
- [ ] Add migration guides from p5.js/Matter.js/ml5.js examples to Swift.
- [ ] Add troubleshooting for toolchains, permissions, GPU availability, model
  compilation, package resolution, and Swift Playgrounds.
- [ ] Add benchmark methodology and current performance results.
- [ ] Add a polished multi-product README with separate installation and quick-start
  sections, screenshots, support status, and release maturity labels.
- [ ] Add complete contribution guidance for APIs, shaders, models, examples,
  documentation, tests, performance, and compatibility updates.
- [ ] Validate every internal DocC link and every external reference in CI.

## 4. P5: core creative-coding runtime

### Lifecycle, timing, and canvas

- [x] `setup()`, `draw()`, frame rate, loop, no-loop, and redraw lifecycle.
- [x] Native AppKit/UIKit canvas and SwiftUI presentation.
- [x] Add `frameCount`, `deltaTime`, measured frame rate, `millis()`, and monotonic
  clock behavior.
- [ ] Add canvas resizing, display scale, pixel density, fullscreen/display metadata,
  and safe-area behavior.
- [x] Define deterministic manual-clock and manual-frame drivers for tests/examples.
- [ ] Add pause/resume behavior for app scene and window lifecycle transitions.
- [ ] Add offscreen graphics buffers and reusable rendering contexts.

### Math, vectors, randomness, and noise

- [x] `P5Vector` construction, arithmetic, magnitude, direction, interpolation,
  random 2D direction, Swift operators, and Core Graphics bridges.
- [x] Complete remaining vector parity needed by the book: component overloads,
  equality helpers, remainder, reflect, spherical interpolation, and random 3D.
- [x] Add `map`, `constrain`, `lerp`, `norm`, 2D/3D distance and magnitude, and
  angle conversion helpers on both `P5Math` and `P5Sketch`.
- [x] Add the remaining min/max, rounding, powers, roots, and trigonometric helpers.
- [x] Add radians/degrees angle mode and propagate it to drawing, trigonometric,
  and explicit context-free vector APIs.
- [x] Add a stable seedable uniform generator, range sampling, collection selection,
  Gaussian values, and per-sketch deterministic random state.
- [ ] Add weighted selection, exponential values, and reproducible generator
  injection.
- [x] Add seedable 1D/2D/3D coherent Perlin noise, octave/falloff detail controls,
  and per-sketch deterministic noise state.
- [ ] Validate statistical properties and deterministic golden sequences.
- [ ] Evaluate Accelerate/BNNS/native SIMD implementations and document choices.

### Colors and drawing style

- [x] Core Graphics color fill/stroke/background and disabled fill/stroke.
- [x] Stroke weight and push/pop drawing state.
- [x] Add numeric grayscale, grayscale/alpha, RGB/RGBA, and hexadecimal colors.
- [x] Add RGB, HSB/HSV, and Display P3 color modes with configurable ranges.
- [x] Add reusable value-semantic `P5Color`, component extraction, interpolation, and accessibility
  contrast helpers.
- [x] Add stroke caps, joins, miter limits, dash patterns, fill rules, and antialiasing
  controls.
- [x] Add native normal, multiply, screen, and additive blend modes plus global opacity.
- [ ] Add tint/no-tint and broader Core Image compositing mappings.

### 2D geometry and paths

- [x] Lines, rectangles, squares, circles, and ellipses.
- [x] Add points, triangles, quads, all arc closures, rounded rectangles, and
  regular polygons.
- [x] Add rectangle and ellipse coordinate modes, including their square, rounded-rectangle,
  circle, and arc forms.
- [ ] Add image coordinate modes after the image subsystem exists.
- [x] Add `beginShape`, vertex, Catmull-Rom curve vertex, Bézier vertex, quadratic vertex,
  contours, and `endShape` close behavior.
- [ ] Add Core Graphics path import/export and reusable shape objects.
- [x] Add scale, shear, apply-matrix, and reset-matrix transform helpers.
- [ ] Add public matrix inspection and reusable transform values.
- [ ] Add geometry tests for flipped native canvas coordinates and pixel alignment.

### Input and interaction

- [x] Add pointer position, previous position, delta, buttons, pressed state, enter,
  exit, move, drag, press, release, and click callbacks.
- [ ] Add multi-touch tracking with stable identifiers and gesture coexistence.
- [x] Add semantic keyboard key/code/modifier state and press/release/type/cancel
  callbacks with AppKit and UIKit native adapters.
- [ ] Add focus, hover, scroll, accessibility actions, drag/drop, and clipboard hooks.
- [x] Map the shared pointer model to mouse, Apple Pencil, trackpad, and indirect
  pointer behavior; retain specialized gesture semantics as follow-up work.
- [x] Make pointer-event delivery main-actor safe, ordered, injectable, and documented.
- [x] Apply main-actor ordering, injection, record/replay values, and cancellation
  safety to keyboard input.
- [ ] Apply the same delivery guarantees to multi-touch collection, gestures,
  scroll, drag/drop, clipboard, and accessibility input.

### Text, images, pixels, and export

- [ ] Add Core Text font loading, fallback, size, leading, alignment, bounds,
  wrapping, measurement, and drawing.
- [ ] Add async CGImage/ImageIO loading from bundle, file, data, and URL.
- [ ] Add image draw/crop/resize, mode, tint, mask, copy, and blend operations.
- [ ] Add pixel density, load/update pixels, typed pixel buffers, and sampling.
- [ ] Add Core Image filters with deterministic CPU-reference tests where practical.
- [ ] Add PNG/JPEG/HEIF export, frame capture, animation/video export, and native
  file/Photos integrations.
- [ ] Define color-space, alpha-premultiplication, orientation, and HDR behavior.

### Native media, audio, data, and interface equivalents

- [ ] Add permission-aware AVFoundation camera and microphone capture.
- [ ] Add video playback, frame extraction, recording, and lifecycle management.
- [ ] Add AVAudioEngine files, oscillators, envelopes, amplitude analysis, and FFT.
- [ ] Add URLSession loading, JSON/text/table parsing, and cancellation.
- [ ] Add UserDefaults and file-backed persistence helpers.
- [ ] Provide SwiftUI/UIKit/AppKit equivalents for buttons, sliders, text fields,
  labels, and other DOM controls used by book examples.
- [ ] Add privacy manifests and permission documentation for accessed resources.

### Metal-backed 3D

- [ ] Define the renderer abstraction without regressing the Core Graphics 2D path.
- [ ] Add Metal device, queue, pipeline, buffers, frame pacing, and error model.
- [ ] Add 3D vectors/matrices, cameras, perspective/orthographic projections, and
  coordinate conventions.
- [ ] Add 3D primitives, indexed meshes, normals, materials, lights, and textures.
- [ ] Add depth, stencil, culling, blending, MSAA, and render-target controls.
- [ ] Add Metal shader APIs and validated model loading.
- [ ] Port the book's 3D/vector and particle examples with native Metal rendering.

## 5. Matter: production physics engine

### Model and API surface

- [x] Vector, identifiers, circle/rectangle definitions, body/world state, forces,
  fixed-step engine, Metal integration kernel, and CPU reference integrator.
- [x] Add angle, angular velocity, torque, inertia, center of mass, area, density,
  restitution, friction, static friction, air friction, and slop.
- [x] Add body labels, plugin/user metadata, sensor state, collision groups/categories,
  masks, and immutable identifiers.
- [x] Add validated circle, rectangle, polygon, trapezoid, and vertices factories.
- [x] Add compound bodies and concave decomposition with documented limitations.
- [x] Add body position/angle/velocity/angular-velocity setters and transforms.
- [x] Add world body add, remove, clear, lookup, stable enumeration, and in-place
  mutation APIs.
- [x] Add exact point, bounds-region, and finite-segment spatial query APIs.
- [x] Add hierarchical composites with stable IDs, cycle prevention, recursive
  body queries, and explicit subtree-removal semantics.
- [x] Add transactional batch body/world mutation APIs that avoid actor round trips.

### Collision system

- [x] Implement deterministic AABB generation and updates.
- [x] Implement a scalable broad phase with benchmarks and worst-case tests.
- [x] Implement circle-circle, circle-polygon, and polygon-polygon narrow phases.
- [x] Implement SAT/support features and deterministic one- or two-point contact
  manifolds.
- [x] Add persistent pairs, contact feature identifiers, and warm starting.
- [x] Implement impulse resolution, static/dynamic friction, restitution,
  positional correction, and configurable velocity/position iteration counts.
- [x] Add persistent warm starting and prove stacking stability under documented
  stress-test tolerances.
- [x] Apply sensors and collision filtering to deterministic collision queries.
- [x] Implement sleeping/waking and island management.
- [x] Add continuous collision detection or explicitly bounded tunneling behavior.
- [x] Emit ordered collision start, active, and end events with stable body
  identifiers and last-known end manifolds.

### Constraints and interaction

- [x] Add point-to-body and body-to-body distance constraints.
- [x] Add stiffness, damping, length, local/world anchors, angular stiffness,
  deterministic solver iterations, and break-impulse limits.
- [x] Add chains, meshes/cloth, bridges, pendulums, springs, and soft-body helpers
  with atomic world and engine insertion.
- [x] Add rotational locks and torque-limited angular motors for windmill examples.
- [x] Add mouse/touch constraints with P5 pointer-coordinate adapters.
- [x] Add attraction/force behaviors used by Chapter 6.

### Execution and rendering

- [x] Define Metal integration and deterministic CPU collision-query/response
  ownership, with no ambiguous silent fallback.
- [x] Add GPU buffers and kernels for the selected broad phase, narrow phase,
  solving, and integration stages where benchmarks justify them.
- [x] Preserve a deterministic CPU reference engine and verify linear/angular
  integration against the Metal kernel within documented tolerances.
- [x] Add runner/manual-step APIs, capped fixed-step accumulation, interpolation,
  pause, reset, and cancellation.
- [x] Add immutable `Sendable` world, simulation-result, and runner-update
  snapshots safe to consume from the main actor.
- [x] Add P5 drawing adapters for bodies, vertices, constraints, contacts, bounds,
  and debug overlays without coupling the Matter target to P5.
- [x] Meet Chapter 6 API needs: `Engine`, `Runner`, `Bodies`, `Body`, `Composite`,
  `Constraint`, `Events`, `MouseConstraint`, and vector operations.

## 6. ML5: trainable native machine learning

### Data and inference

- [x] Typed scalar features/outputs, classification/regression decoding, actor-based
  Core ML prediction, cancellation checks, and compute-unit configuration.
- [x] Add ordered feature schemas, tensor shapes, arrays, dictionaries, sequences,
  images, pixel buffers, and missing/default-value policies.
- [x] Add dataset accumulation/removal/shuffle/split APIs corresponding to `addData`.
- [x] Add fitted normalization statistics, `normalizeData`, denormalization, and
  serializable preprocessing pipelines.
- [x] Add batch prediction and a low-latency immutable synchronous inference
  snapshot suitable for a draw loop.
- [x] Add classification top-k, calibrated confidence, regression vectors, and
  evaluation metrics.

### Native training

- [x] Define dense-network configuration: inputs, outputs, hidden layers,
  activations, initialization, loss, optimizer, learning rate, batch size, epochs,
  validation, and deterministic seed.
- [x] Implement classification and regression training with MPSGraph/Metal-backed
  Apple APIs, plus a deterministic small CPU reference trainer for tests.
- [ ] Expose async progress, metrics, early stopping, cancellation, checkpoints,
  and explicit device/fallback selection.
- [ ] Support model save/load and conversion or export to Core ML where supported.
- [ ] Validate trained-model numerical quality on canonical datasets.

### Neuroevolution

- [ ] Add weight/topology snapshot and deep-copy support.
- [ ] Add deterministic mutation strategies and configurable mutation rates/scales.
- [ ] Add crossover strategies with topology compatibility validation.
- [ ] Add synchronous `predict` and `classify` paths for evolved agents.
- [ ] Add serialization for populations/brains and reproducible resume.
- [ ] Meet Chapters 10–11 API needs: neural-network creation, `addData`, normalization,
  training, classify/predict sync and async, copy, mutate, and crossover.

### Model ecosystem

- [ ] Add bundled/resource/file/URL compiled-model loading with integrity checks.
- [ ] Add Vision/Core ML adapters for image classification and feature extraction.
- [ ] Add model metadata, licenses, provenance, versioning, and cache management.
- [ ] Document Create ML/macOS-only workflows separately from on-device APIs.
- [ ] Add privacy, memory, thermal, and Neural Engine availability guidance.

## 7. Nature of Code API reference

- [x] Remove exhaustive example manifests, browser work, and 344 example ports from
  release scope at the project owner's direction.
- [ ] Keep the pinned upstream audit as a requirements checklist for library APIs.
- [ ] Add a small focused smoke sample for each major library capability; samples
  demonstrate the API but are not line-by-line book ports.
- [ ] Add a book-version compatibility page and clearly attribute Daniel Shiffman
  and the Nature of Code project without implying official affiliation.

## 8. Apple-platform product polish

- [ ] Review every API against the Swift API Design Guidelines and Apple framework
  naming/concurrency conventions.
- [ ] Prefer value semantics, `Sendable`, actors, async/await, typed errors, and
  explicit ownership; document deliberate exceptions.
- [ ] Add availability annotations and graceful capability checks for Metal, Core ML,
  MPSGraph, camera, microphone, Photos, and platform-specific UI.
- [ ] Support Dynamic Type, VoiceOver, Reduce Motion, increased contrast, keyboard
  navigation, pointer input, and localization in the example browser.
- [ ] Verify display scale, color management, wide color, dark mode, HDR decisions,
  and energy behavior.
- [ ] Add Instruments-based performance, allocations, leaks, GPU, and energy audits.
- [ ] Add package icons, consistent diagrams/screenshots, copy editing, and polished
  error/troubleshooting language.
- [ ] Verify clean integration in Xcode apps, SwiftPM clients, Swift Playgrounds,
  and an archived sample application.
- [ ] Complete security, privacy, license, attribution, and third-party model audits.

## 9. Release gates

- [ ] All preceding checklist items are complete or moved to an explicitly approved
  post-1.0 scope with rationale and no contradiction of public compatibility claims.
- [ ] All three products pass clean Debug/Release builds and tests on every supported
  platform/toolchain matrix entry.
- [ ] Coverage and documentation completeness gates report 100% for all products.
- [ ] Focused package smoke samples compile and their required runtime/visual suites
  pass; exhaustive Nature of Code ports are not a release gate.
- [ ] API digester reports no unreviewed breaking changes.
- [ ] Performance and memory regressions remain within documented budgets.
- [ ] SPI and hosted documentation smoke tests pass for the release candidate.
- [ ] A fresh external sample project resolves the tag and imports each product
  independently.
- [ ] Changelog, migration notes, semantic version, release notes, checksums,
  attribution, and support status are accurate.
- [ ] Tag and publish 1.0 only after the complete release-validation script passes.

## 10. Independent repository migration

- [ ] Create history-preserving local `p5.swift`, `matter.swift`, and `ml5.swift`
  repositories after implementation work is complete.
- [ ] Give each repository a single-product `Package.swift`, lock state, source,
  tests, DocC catalog, shared scheme, test plan, examples, and API baseline.
- [ ] Give each repository independent format, lint, coverage, documentation,
  compatibility, benchmark, and release-validation scripts.
- [ ] Give each repository independent GitHub Actions for supported macOS/iOS
  builds, tests, coverage, DocC publishing, API checks, and releases.
- [ ] Give each repository its own `.spi.yml`, badges, documentation routes,
  semantic-version policy, changelog, release manifest, and provenance flow.
- [ ] Add reciprocal, tested links among all three READMEs and DocC landing pages.
- [ ] Ensure no repository's validation depends on sibling checkout paths or state.
- [ ] Validate each repository from a clean clone and from an external SwiftPM client.
- [ ] Leave an archival migration notice in the combined repository that points to
  the three independently maintained successors.
