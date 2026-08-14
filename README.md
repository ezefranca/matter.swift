# P5Swift

P5Swift is a lightweight, native Swift drawing library inspired by
[p5.js](https://p5js.org). It provides the familiar `setup()` / `draw()`
lifecycle and a focused set of p5-style drawing functions backed by Core
Graphics.

The package uses Swift 6 and supports iOS 17+ and macOS 14+.

## Installation

In Xcode, choose **File > Add Package Dependencies** and enter:

```text
https://github.com/ezefranca/P5Swift
```

You can also add the package to `Package.swift`:

```swift
.package(
    url: "https://github.com/ezefranca/P5Swift",
    from: "0.2.0"
)
```

## Create a sketch

Subclass `P5Sketch`, override `setup()` for one-time configuration, and
override `draw()` for frame-by-frame drawing:

```swift
import P5Swift
import UIKit

@MainActor
final class BouncingCircle: P5Sketch {
    private var x: CGFloat = 0

    override func setup() {
        frameRate(60)
        noStroke()
        fill(UIColor.systemPink.cgColor)
    }

    override func draw() {
        background(UIColor.systemBackground.cgColor)
        circle(x, height / 2, 40)

        x = (x + 2).truncatingRemainder(dividingBy: width)
    }
}
```

Add the sketch's native view to your interface:

```swift
final class SketchViewController: UIViewController {
    private var sketch: BouncingCircle?

    override func viewDidLoad() {
        super.viewDidLoad()

        let sketch = BouncingCircle(size: view.bounds.size)
        sketch.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sketch.view)
        self.sketch = sketch
    }
}
```

Keep a strong reference to the sketch for as long as it is displayed.

## p5.js compatibility

P5Swift intentionally follows p5.js terminology and geometry:

| P5Swift | p5.js reference | Notes |
| --- | --- | --- |
| `setup()`, `draw()` | [`setup()`](https://p5js.org/reference/p5/setup/), [`draw()`](https://p5js.org/reference/p5/draw/) | Same lifecycle roles |
| `frameRate(_:)` | [`frameRate()`](https://p5js.org/reference/p5/frameRate/) | Sets a target rate |
| `loop()`, `noLoop()`, `redraw()` | [`loop()`](https://p5js.org/reference/p5/loop/), [`noLoop()`](https://p5js.org/reference/p5/noLoop/), [`redraw()`](https://p5js.org/reference/p5/redraw/) | Controls frame production |
| `line`, `rect`, `square` | [2D primitives](https://p5js.org/reference/#Shape) | Core Graphics coordinates, in points |
| `circle` | [`circle()`](https://p5js.org/reference/p5/circle/) | Third argument is the **diameter** |
| `ellipse` | [`ellipse()`](https://p5js.org/reference/p5/ellipse/) | Center-based by default |
| `fill`, `noFill`, `stroke`, `noStroke`, `strokeWeight` | [Color](https://p5js.org/reference/#Color) | Uses `CGColor` rather than p5 color values |
| `translate`, `rotate`, `push`, `pop` | [Transform](https://p5js.org/reference/#Transform) | Angles are radians |

The default style matches p5.js: white fill, black one-point stroke.
`push()` and `pop()` preserve both transformations and drawing styles.

P5Swift is not a JavaScript runtime or a complete p5.js port. Browser APIs,
DOM helpers, WebGL, media capture, and the full p5.js function catalog are
outside the current scope.

## Documentation

Public symbols include DocC comments with links to their p5.js counterparts.
In Xcode, choose **Product > Build Documentation** to browse the complete API.

## Demo

`P5Demo` includes Game of Life, Starfield, Fourier series, and fractal tree
examples.
