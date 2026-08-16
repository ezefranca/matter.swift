# p5.swift

> [!IMPORTANT]
> **p5.swift is an expanded fork of
> [Juan Hurtado's P5Swift](https://github.com/juandahurt/P5Swift).**
> The original project established the Core Graphics sketch model that this
> package continues to develop.

[![Tests](https://github.com/ezefranca/p5.swift/actions/workflows/tests.yml/badge.svg)](https://github.com/ezefranca/p5.swift/actions/workflows/tests.yml)
[![Documentation](https://img.shields.io/badge/documentation-DocC-0A84FF.svg?logo=swift&logoColor=white)](https://ezefranca.com/p5.swift/documentation/p5/)
[![Release](https://github.com/ezefranca/p5.swift/actions/workflows/release.yml/badge.svg)](https://github.com/ezefranca/p5.swift/actions/workflows/release.yml)
[![Latest release](https://img.shields.io/github/v/release/ezefranca/p5.swift)](https://github.com/ezefranca/p5.swift/releases)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%2B%20%7C%20macOS%2014%2B-000000?logo=apple&logoColor=white)
![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-brightgreen)
[![Coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)](Scripts/check_coverage.py)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

p5.swift brings the lifecycle and creative-coding vocabulary of
[p5.js](https://p5js.org) to native Swift. It provides a main-actor sketch
model, Core Graphics rendering, SwiftUI integration, and native AppKit and
UIKit canvases.

This repository is a single Swift package that ships three independent
library products, each mapped to a well-known JavaScript creative-coding or
ML library:

| Product | Inspired by | Status |
| --- | --- | --- |
| [`P5`](#create-a-sketch) | [p5.js](https://p5js.org) | Active, see the [parity roadmap](#p5-parity-roadmap) |
| [`Matter`](#matter-physics) | [Matter.js](https://brm.io/matter-js/) | Early, Metal-first physics core |
| [`ML5`](#ml5-on-device-machine-learning) | [ml5.js](https://ml5js.org/) | Active, typed Core ML inference foundation |

Each product is a separate SwiftPM target with its own tests and DocC
catalog. Add only the products you need to your target's dependencies.

## Requirements

| Tool or platform | Minimum version |
| --- | --- |
| Swift | 6.2 |
| Xcode | 26 |
| iOS | 17 |
| macOS | 14 |

## Add the package

In Xcode, choose **File > Add Package Dependencies** and enter:

```text
https://github.com/ezefranca/p5.swift
```

For another Swift package:

```swift
dependencies: [
    .package(
        url: "https://github.com/ezefranca/p5.swift",
        from: "0.3.2"
    )
]
```

Add the `P5` product to your target, then import the module:

```swift
import P5
```

To use the physics or machine-learning packages instead, add `Matter` or
`ML5` and import the corresponding module. All three products live in this
one repository and share the same version tag.

## Create a sketch

```swift
import CoreGraphics
import P5

@MainActor
final class OrbitSketch: P5Sketch {
    private var angle: CGFloat = 0

    override func setup() {
        frameRate(60)
        noStroke()
        fill(CGColor(red: 1, green: 0.2, blue: 0.5, alpha: 1))
    }

    override func draw() {
        background(CGColor(gray: 0.08, alpha: 1))

        let radius: CGFloat = 80
        let x = width / 2 + cos(angle) * radius
        let y = height / 2 + sin(angle) * radius
        circle(x, y, 32)
        angle += 0.03
    }
}
```

## SwiftUI

Use `P5SketchView` to own and present a sketch:

```swift
import P5
import SwiftUI

struct ContentView: View {
    private let canvasSize = CGSize(width: 600, height: 400)

    var body: some View {
        P5SketchView(
            size: canvasSize,
            makeSketch: OrbitSketch.init(size:)
        )
        .accessibilityLabel("A circle orbiting on a dark canvas")
    }
}
```

Pass a `GeometryReader` size for a flexible canvas. A size change creates a
new fixed-size sketch.

## UIKit and AppKit

Every sketch exposes its native canvas through `view`:

```swift
let sketch = OrbitSketch(size: view.bounds.size)
view.addSubview(sketch.view)
```

Keep a strong reference to the sketch while displaying its view.

## Swift Playgrounds

Create an App project, add this repository as a package dependency, import
`P5`, and use `P5SketchView` as the root SwiftUI content. The
[SwiftUI and Swift Playgrounds](https://ezefranca.com/p5.swift/documentation/p5/swiftuiandplaygrounds/)
article includes complete App and Xcode playground examples.

## p5.js compatibility

p5.swift follows p5.js terminology and geometry where it maps cleanly to
Swift. For example, `circle()` accepts a diameter, default drawing styles
match p5.js, and `push()` / `pop()` preserve styles and transformations.

The goal is near-complete native capability parity:

| p5.js capability | Native implementation direction |
| --- | --- |
| 2D canvas and typography | Core Graphics and Core Text |
| DOM and HTML controls | SwiftUI, UIKit, and AppKit |
| WebGL | Metal |
| Camera, microphone, and audio | AVFoundation |
| Files, photos, and export | Native importers, exporters, and Photos |
| Fetch and persistence | URLSession, UserDefaults, and file storage |

Literal browser objects such as `window`, HTML elements, and CSS do not exist
on Apple platforms. Their underlying capabilities can still receive native
APIs.

## P5 parity roadmap

The project is currently in **Phase 1**. Checked items are available in the
latest release; unchecked items are planned. Every new API must include
behavioral tests, p5.js reference links, and documentation of intentional
native differences.

### Phase 1: Complete the 2D foundation

- [x] Sketch lifecycle with `setup()` and `draw()`
- [x] Frame-rate, loop, no-loop, and redraw controls
- [x] Core primitives: lines, rectangles, squares, circles, and ellipses
- [x] Fill, stroke, stroke weight, and disabled fill or stroke
- [x] Translation, rotation, and drawing-state stacks
- [ ] Numeric and grayscale colors, alpha overloads, and color modes
- [ ] Points, triangles, quads, arcs, rounded rectangles, and shape modes
- [ ] `beginShape()`, vertices, curves, Bézier paths, contours, and
  `endShape()`
- [ ] Scale, shear, matrix operations, angle modes, line caps, and line joins
- [ ] Text loading, measurement, alignment, wrapping, and drawing
- [ ] Image loading, drawing, resizing, tinting, masking, and blend modes
- [x] Mouse, touch, keyboard, focus, timing, and canvas-resize events

### Phase 2: Creative-coding utilities

- [x] `P5Vector` and vector arithmetic
- [ ] Seeded random values, Gaussian generation, and noise
- [ ] Mapping, interpolation, constraints, normalization, and trigonometry
- [ ] Date, time, frame count, delta time, and display information
- [ ] Pixel access, filters, image sampling, and color interpolation
- [ ] Offscreen graphics buffers and reusable drawing contexts
- [x] Image, GIF, and native video export

### Phase 3: Native media and audio

- [ ] Camera and microphone capture with AVFoundation
- [ ] Video playback, frame extraction, and recording
- [ ] Audio files, oscillators, amplitude analysis, and FFT data
- [ ] Permission-aware asynchronous APIs and lifecycle management
- [x] Photos and file importer/exporter integration

### Phase 4: Metal-backed 3D

- [ ] 3D primitives, meshes, cameras, projections, materials, and lights
- [ ] Textures and offscreen render targets
- [ ] Shader APIs adapted for Metal Shading Language
- [ ] Model loading and normal generation
- [ ] Depth, stencil, blending, and antialiasing controls

### Phase 5: Native interface integrations

- [x] SwiftUI sketch presentation
- [x] UIKit and AppKit canvas adapters
- [ ] Observable sketch state and native controls
- [ ] Accessibility descriptions and reduced-motion behavior
- [ ] Drag and drop, clipboard, file dialogs, and sharing
- [ ] URLSession networking and native persistence helpers

Read the complete
[parity and compatibility policy](https://ezefranca.com/p5.swift/documentation/p5/p5parityroadmap/)
in the DocC documentation.

## Matter: physics

`Matter` is a native Swift, Metal-first conceptual port of
[Matter.js](https://brm.io/matter-js/). It has no SpriteKit dependency and
does not include Matter.js source code.

The current slice provides `Sendable` vectors, identifiers, body
definitions, bodies, and worlds; Matter-style circle and rectangle
factories; force accumulation with fixed-step semi-implicit Euler
integration; an actor-owned `Engine` with a required Metal execution path
and a bundled Metal kernel; and a deterministic CPU
`ReferenceIntegrator` for tests and numerical comparison. Collision
detection, constraints, sleeping, compound bodies, and rendering are
intentionally outside this initial slice.

```swift
import Matter

let engine = try Engine(gravity: Vector(x: 0, y: 9.81))
let ball = try await engine.add(Bodies.circle(at: .zero, radius: 12, mass: 1))
try await engine.applyForce(Vector(x: 20, y: 0), to: ball)
let world = try await engine.step()
```

`Engine` never falls back to CPU work. Catch `MetalBackendError` to handle an
unavailable device, kernel compilation failure, or failed command buffer.
`Matter` requires a Metal-capable device.

## ML5: on-device machine learning

`ML5` provides native Swift foundations for approachable, on-device machine
learning built directly on Core ML. It is an independent implementation
inspired by the conceptual ergonomics of [ml5.js](https://ml5js.org/).

The current inference foundation supports validated scalars, numeric arrays,
dictionaries, shaped tensors, homogeneous sequences, and immutable image pixels.
It also provides ordered schemas with exact tensor-shape checks and explicit
missing/default/unknown-field policies, typed classification and regression
decoding, and async actor-isolated prediction.

```swift
import ML5

let task = ClassificationTask<String>(
    configuration: try ClassificationConfiguration(
        labelOutput: "label",
        confidenceOutput: "confidence"
    )
)

let network = try NeuralNetwork(task: task, modelAt: compiledModelURL)
let prediction = try await network.predict(
    try FeatureVector(["feature": .number(0.5)])
)

print(prediction.label, prediction.confidence as Any)
```

All structured boundary values are `Sendable` and `Codable`; decoding runs the
same validation as ordinary construction. `ML5Image` copies between owned bytes
and `CVPixelBuffer`, including an explicit RGBA-to-BGRA conversion for Core Video.

`ML5Dataset` provides actor-isolated `add`/remove operations, stable sample IDs,
atomic batch insertion, reproducible seeded shuffling, train/validation/test
splits, and validated Codable snapshots for checkpointing.

`FeaturePreprocessingPipeline` fits reversible standard-score and configurable
min-max normalization for numbers, arrays, numeric dictionaries, and tensors.
Fitted statistics and pipeline stages are immutable, Sendable, Codable, and
validated again when decoded.

Prediction supports ordered batches. Snapshot-capable backends can also vend a
typed `NeuralNetworkInferenceSnapshot` for synchronous draw-loop inference without
an actor hop; backends that cannot do so report an explicit unsupported operation.

Ranked classification supports normalized probability dictionaries,
temperature-scaled logits, stable top-k ordering, confusion matrices, and per-label
precision/recall/F1 metrics. Ordered regression-vector tasks and scalar/vector
evaluation provide MAE, MSE, RMSE, R², and per-component summaries.

Dense-network configuration covers ordered inputs and outputs, hidden layers,
activations, deterministic initialization, compatible regression/classification
losses, SGD or Adam optimization, learning rate, batches, epochs, validation split,
and seed. Every configuration is validated, `Sendable`, `Hashable`, and `Codable`.
`DenseNetworkModel` adds immutable, shape-checked parameters plus async, batch, and
lock-free synchronous snapshot inference across every supported activation.

`DenseCPUTrainer` provides reproducible mini-batch classification and regression
training with Glorot, He, or zero initialization; momentum SGD or Adam; all configured
losses; held-out validation history; and cooperative cancellation. It is the numerical
reference backend for small models and accelerated-backend parity.
`DenseMPSGraphTrainer` runs batched forward and automatic-differentiation graphs on
an explicitly selected Metal device and command queue, while preserving the same
validated model format and optimizer semantics. Both backends support serial async
progress, cooperative cancellation, early stopping, and `Codable` exact-resume
checkpoints containing optimizer state and dataset identity. `DenseTrainer` provides
explicit CPU, Metal, or automatic selection with a declared fallback policy; fallback
is considered only before training begins, never after a graph or numerical failure.

Persist trained models as versioned, integrity-checked JSON with
`DenseModelArchive`. `ML5ModelMetadata` records ownership, license, provenance, and
application version. For Apple deployment, export any validated dense model as a
self-contained `.mlmodel` specification and ask Core ML to compile it natively:

```swift
let metadata = try ML5ModelMetadata(
    name: "MyClassifier",
    version: "1.0.0",
    author: "Example Team",
    license: "MIT"
)
try result.model.archived(metadata: metadata).write(to: archiveURL)

let export = try DenseCoreMLExportConfiguration(metadata: metadata)
try result.model.writeCoreMLModel(to: modelURL, configuration: export)
```

Core ML receives a single float32 multi-array in the configured input-feature order
and returns a multi-array in output-name order. Compilation tests exercise every ML5
dense activation against `MLModel` and check numerical parity with native ML5 inference.
Training quality is gated independently on canonical XOR and held-out affine datasets,
with CPU/Metal predictions and loss histories compared on Metal-capable CI hosts.

`DenseBrain` turns a trained dense model into an immutable neuroevolution value with
synchronous `predict` and ordered softmax `classify` calls for agent update loops.
Seeded Gaussian, uniform, or reset mutation and uniform, single-point, or blend
crossover return independent children. Versioned `DenseBrainSnapshot` and homogeneous
`DenseBrainPopulation` values are `Codable`; population archives retain their random
state so mutation resumes reproducibly after decoding.

Third-party Core ML assets can be described with `ML5ModelSource`, which requires a
lowercase SHA-256 `ML5ModelDigest` and the same ownership/license/provenance metadata
used by dense archives. `ML5ModelCache` resolves bundle, file, package, compiled, and
HTTPS `.mlmodel` sources behind an actor; verifies before compilation; rehashes compiled
cache entries on every hit; and provides bounded inventory and explicit eviction APIs.

`NeuralNetwork` is actor-isolated and checks cancellation before and after
model prediction. ML5-owned dense networks are trainable, but ML5 does not claim that
an arbitrary loaded Core ML model can be retrained: calling `NeuralNetwork.train(_:)`
currently throws
`ML5Error.unsupportedOperation(.onDeviceTraining)`.
`NeuralNetworkTrainingAdapter` is the extension point for a future Create ML
adapter that can return a `ModelPredicting` backend.

## Documentation

The DocC documentation is published at
[ezefranca.com/p5.swift](https://ezefranca.com/p5.swift/documentation/p5/).
GitHub Actions rebuilds it from `main`.

Swift Package Index also builds and hosts versioned
[DocC documentation](https://swiftpackageindex.com/ezefranca/p5.swift/documentation)
from the `P5`, `Matter`, and `ML5` targets configured in `.spi.yml`.

The public site also publishes
[agent-readable documentation](https://ezefranca.com/p5.swift/llms.txt),
[complete source context](https://ezefranca.com/p5.swift/llms-full.txt), and
[structured package metadata](https://ezefranca.com/p5.swift/agent-context.json).

In Xcode, choose **Product > Build Documentation** to build it locally.

Run the test suite and its coverage gate with:

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

The manifest declares the Swift Testing release matching the package's minimum
Swift toolchain, so the same command works with full Xcode and standalone
Command Line Tools installations.

## Distribution

p5.swift is distributed as a source package through Swift Package Manager.
Semantic version tags are published as GitHub Releases by the release
workflow.

The repository includes `.spi.yml` metadata for
[Swift Package Index](https://swiftpackageindex.com/ezefranca/p5.swift).
After the GitHub repository is renamed and public, submit its URL through
[Add a Package](https://swiftpackageindex.com/add-a-package).

GitHub Packages does not currently provide a Swift package registry. Using an
unrelated GitHub Packages format would not be consumable by SwiftPM, so the
repository follows Swift's standard tag-and-release distribution model.

## Attribution

p5.swift builds on
[Juan Hurtado's P5Swift](https://github.com/juandahurt/P5Swift), including its
original Core Graphics renderer and demo sketches. The project is inspired by
[p5.js](https://p5js.org) and the creative-coding work of
[Daniel Shiffman](https://github.com/shiffman).

## Contributing and license

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) and the
[security policy](SECURITY.md) before opening a change.

p5.swift is available under the MIT License. See [LICENSE](LICENSE).
