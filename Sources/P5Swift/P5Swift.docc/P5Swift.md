# ``P5Swift``

Build native Core Graphics sketches with a lifecycle and vocabulary modeled
after p5.js.

## Overview

Create a ``P5Sketch`` subclass and override ``P5Sketch/setup()`` and
``P5Sketch/draw()``. P5Swift displays the sketch through a native
``P5Sketch/view`` and schedules frames on the main actor.

```swift
@MainActor
final class MySketch: P5Sketch {
    override func setup() {
        frameRate(60)
    }

    override func draw() {
        circle(width / 2, height / 2, 80)
    }
}
```

P5Swift follows p5.js geometry where practical. In particular,
``P5Sketch/circle(_:_:_:)`` accepts a diameter, and ``P5Sketch/push()`` /
``P5Sketch/pop()`` preserve styles as well as transformations.

## Topics

### Creating a sketch

- ``P5Sketch``
- ``P5CanvasView``

### Lifecycle and timing

- ``P5Sketch/setup()``
- ``P5Sketch/draw()``
- ``P5Sketch/frameRate(_:)``
- ``P5Sketch/loop()``
- ``P5Sketch/noLoop()``
- ``P5Sketch/redraw()``

### Drawing

- ``P5Sketch/background(_:)``
- ``P5Sketch/line(_:_:_:_:)``
- ``P5Sketch/rect(_:_:_:_:)``
- ``P5Sketch/square(_:_:_:)``
- ``P5Sketch/circle(_:_:_:)``
- ``P5Sketch/ellipse(_:_:_:_:)``

### Styling and transformations

- ``P5Sketch/fill(_:)``
- ``P5Sketch/noFill()``
- ``P5Sketch/stroke(_:)``
- ``P5Sketch/noStroke()``
- ``P5Sketch/strokeWeight(_:)``
- ``P5Sketch/translate(_:_:)``
- ``P5Sketch/rotate(_:)``
- ``P5Sketch/push()``
- ``P5Sketch/pop()``
