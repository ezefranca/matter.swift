# Drawing Matter Snapshots with P5

Render physics without adding a P5 dependency to Matter.

## Renderer-neutral snapshots

``MatterDrawingAdapter`` converts an immutable ``World`` and optional collision
snapshot into value-semantic ``MatterDrawingCommand`` values. The commands retain
their semantic layer and stable body, constraint, or collision identity, making
them suitable for interactive rendering, debugging, recording, or export.

Use ``MatterDrawingOptions/standard`` for body geometry and constraints, or
``MatterDrawingOptions/debug`` to add polygon vertices, contact points and
penetration normals, and broad-phase bounds:

```swift
let result = try await engine.stepWithEvents()
let commands = try MatterDrawingAdapter.commands(
    for: result.world,
    collisions: result.collisions,
    options: .debug
)
```

Commands never retain the world or renderer. Build them off the main actor, then
pass the immutable array to the UI that owns the drawing surface.

## P5 adapter

Keep the cross-library adapter in the application or sample target that imports
both `Matter` and `P5`. The following complete mapping uses only public APIs and
does not make either production library depend on the other:

```swift
import Matter
import P5

@MainActor
func draw(_ commands: [MatterDrawingCommand], on sketch: P5Sketch) {
    for command in commands {
        switch command.primitive {
        case let .circle(center, radius):
            sketch.circle(
                CGFloat(center.x),
                CGFloat(center.y),
                CGFloat(radius * 2)
            )
        case let .polygon(vertices):
            sketch.beginShape()
            for vertex in vertices {
                sketch.vertex(CGFloat(vertex.x), CGFloat(vertex.y))
            }
            sketch.endShape(.close)
        case let .segment(start, end):
            sketch.line(
                CGFloat(start.x), CGFloat(start.y),
                CGFloat(end.x), CGFloat(end.y)
            )
        case let .point(position):
            sketch.point(CGFloat(position.x), CGFloat(position.y))
        case let .bounds(bounds):
            let minimum = bounds.minimum
            let maximum = bounds.maximum
            sketch.line(CGFloat(minimum.x), CGFloat(minimum.y), CGFloat(maximum.x), CGFloat(minimum.y))
            sketch.line(CGFloat(maximum.x), CGFloat(minimum.y), CGFloat(maximum.x), CGFloat(maximum.y))
            sketch.line(CGFloat(maximum.x), CGFloat(maximum.y), CGFloat(minimum.x), CGFloat(maximum.y))
            sketch.line(CGFloat(minimum.x), CGFloat(maximum.y), CGFloat(minimum.x), CGFloat(minimum.y))
        }
    }
}
```

Choose fill, stroke, weight, opacity, and dash patterns from
``MatterDrawingCommand/layer`` before drawing each primitive. For example, body
geometry can use the sketch's normal style while contacts and bounds use bright,
unfilled debug strokes.
