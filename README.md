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
- [ ] Mouse, touch, keyboard, focus, timing, and canvas-resize events

### Phase 2: Creative-coding utilities

- [ ] `P5Vector` and vector arithmetic
- [ ] Seeded random values, Gaussian generation, and noise
- [ ] Mapping, interpolation, constraints, normalization, and trigonometry
- [ ] Date, time, frame count, delta time, and display information
- [ ] Pixel access, filters, image sampling, and color interpolation
- [ ] Offscreen graphics buffers and reusable drawing contexts
- [ ] Image and animation export

### Phase 3: Native media and audio

- [ ] Camera and microphone capture with AVFoundation
- [ ] Video playback, frame extraction, and recording
- [ ] Audio files, oscillators, amplitude analysis, and FFT data
- [ ] Permission-aware asynchronous APIs and lifecycle management
- [ ] Photos and file importer/exporter integration

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

## Documentation

The DocC documentation is published at
[ezefranca.com/p5.swift](https://ezefranca.com/p5.swift/documentation/p5/).
GitHub Actions rebuilds it from `main`.

Swift Package Index also builds and hosts versioned
[DocC documentation](https://swiftpackageindex.com/ezefranca/p5.swift/documentation)
from the `P5` target configured in `.spi.yml`.

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
```

Full Xcode toolchains include Swift Testing. If a standalone Command Line
Tools installation omits that module, set
`P5_USE_SWIFT_TESTING_PACKAGE=1` to use the upstream test package while
developing locally.

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
