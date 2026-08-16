# Migrating JavaScript examples to Swift

These examples show the structural changes common to p5.js, Matter.js, and ml5.js
ports. Consult each product's DocC compatibility article for exact capabilities.

## p5.js to P5

Move global functions and variables into a main-actor ``P5Sketch`` subclass. Replace
dynamic numbers with `CGFloat`, callback loading with throwing async work, DOM controls
with SwiftUI/UIKit/AppKit, and WebGL shaders with Metal Shading Language.

```javascript
function setup() { createCanvas(400, 300); }
function draw() { background(20); circle(mouseX, mouseY, 24); }
```

```swift
@MainActor
final class PointerSketch: P5Sketch {
    override func draw() {
        background(20)
        circle(pointerPosition.x, pointerPosition.y, 24)
    }
}
```

The host chooses the canvas size when constructing the sketch. Permission-bearing and
I/O operations return typed failures and support cancellation.

## Matter.js to Matter

Replace mutable object bags and plugin access with validated definitions, stable IDs,
and actor calls. Read immutable snapshots after a step.

```swift
let engine = try Engine(gravity: Vector(x: 0, y: 9.81))
let identifier = try await engine.add(
    Bodies.circle(at: .zero, radius: 12, mass: 1)
)
try await engine.applyForce(Vector(x: 4, y: 0), to: identifier)
let world = try await engine.step()
let body = world.body(withID: identifier)
```

Drive ``Runner`` from the display clock or step a fixed number of ticks directly.
Collision events are ordered values/async streams rather than string-keyed emitter
payloads. Rendering is application-owned through drawing-command snapshots.

## ml5.js to ML5

Define feature and output schemas instead of passing loosely typed dictionaries.
Dataset mutation is actor-isolated; configuration and fitted preprocessing are values.
Training and prediction are throwing async operations.

```swift
let dataset = ML5Dataset<DenseTrainingSample>()
_ = try await dataset.add(
    DenseTrainingSample(
        features: FeatureVector(["x": .number(1)]),
        targets: [3]
    )
)
let snapshot = await dataset.snapshot()
let result = try await DenseCPUTrainer().train(
    snapshot.entries.map(\.sample),
    configuration: configuration
)
```

Core ML files require exact feature names and task decoders. A loaded arbitrary Core
ML model is not implicitly trainable. Remote models require HTTPS, integrity, license,
and provenance metadata.

## Cross-product applications

Import each needed package product in the application. Convert P5 pointer coordinates
to Matter values and transform Matter drawing commands in the UI layer. Convert ML5
predictions into application decisions before mutating a Matter engine. These adapters
stay outside the independent libraries, avoiding hidden lifecycle or version coupling.
