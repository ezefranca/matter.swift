# p5.swift

> [!IMPORTANT]
> **p5.swift is an expanded fork of
> [Juan Hurtado's P5Swift](https://github.com/juandahurt/P5Swift).**
> The original project established the Core Graphics sketch model that this
> package continues to develop.

[![Tests](https://github.com/ezefranca/P5Swift/actions/workflows/tests.yml/badge.svg)](https://github.com/ezefranca/P5Swift/actions/workflows/tests.yml)
[![Documentation](https://img.shields.io/badge/documentation-DocC-0A84FF.svg?logo=swift&logoColor=white)](https://ezefranca.com/P5Swift/documentation/p5/)
[![Release](https://github.com/ezefranca/P5Swift/actions/workflows/release.yml/badge.svg)](https://github.com/ezefranca/P5Swift/actions/workflows/release.yml)
[![Latest release](https://img.shields.io/github/v/release/ezefranca/P5Swift)](https://github.com/ezefranca/P5Swift/releases)
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
https://github.com/ezefranca/P5Swift
```

For another Swift package:

```swift
dependencies: [
    .package(
        url: "https://github.com/ezefranca/P5Swift",
        from: "0.3.1"
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
[SwiftUI and Swift Playgrounds](https://ezefranca.com/P5Swift/documentation/p5/swiftuiandplaygrounds/)
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

See the
[parity roadmap](https://ezefranca.com/P5Swift/documentation/p5/p5parityroadmap/)
for the planned implementation sequence.

## Documentation

The DocC documentation is published at
[ezefranca.com/P5Swift](https://ezefranca.com/P5Swift/documentation/p5/).
GitHub Actions rebuilds it from `main`.

Swift Package Index also builds and hosts versioned
[DocC documentation](https://swiftpackageindex.com/ezefranca/P5Swift/documentation)
from the `P5` target configured in `.spi.yml`.

The public site also publishes
[agent-readable documentation](https://ezefranca.com/P5Swift/llms.txt),
[complete source context](https://ezefranca.com/P5Swift/llms-full.txt), and
[structured package metadata](https://ezefranca.com/P5Swift/agent-context.json).

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
[Swift Package Index](https://swiftpackageindex.com/ezefranca/P5Swift).
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
