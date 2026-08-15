# Compound Bodies

Combine convex primitives into one rigid body or deterministically decompose a
simple concave polygon.

## Assemble primitives

Each ``CompoundPart`` has convex geometry plus a body-local translation and
clockwise rotation. ``Bodies/compound(at:parts:angle:mass:isStatic:)`` combines
two or more parts under one body identifier, material, transform, velocity,
mass, and inertia.

```swift
let capsule = try Bodies.compound(
    at: Vector(x: 100, y: 80),
    parts: [
        CompoundPart(shape: .circle(radius: 10), position: Vector(x: -20, y: 0)),
        CompoundPart(shape: .rectangle(width: 40, height: 20)),
        CompoundPart(shape: .circle(radius: 10), position: Vector(x: 20, y: 0)),
    ],
    mass: 3
)
```

Part areas are summed. Mass is distributed by part area when calculating the
compound moment of inertia, with the parallel-axis contribution of each part's
local position. Arrange parts around the body-local origin because Matter treats
that origin as the center of mass; it does not recenter client geometry.

## Decompose concave vertices

``Bodies/fromVertices(at:vertices:angle:mass:isStatic:)`` retains convex input
as one polygon and ear-clips concave input into a compound of triangles:

```swift
let shape = try Bodies.fromVertices(
    at: .zero,
    vertices: [
        Vector(x: -20, y: -20),
        Vector(x: 20, y: -20),
        Vector(x: 20, y: 0),
        Vector(x: 0, y: 0),
        Vector(x: 0, y: 20),
        Vector(x: -20, y: 20),
    ]
)
```

``ConcaveDecomposer/decompose(_:)`` is deterministic for clockwise and
counterclockwise input. It rejects fewer than three vertices, nonfinite or
duplicate points, adjacent collinear edges, self-intersections, and zero area.

The implementation supports one simple outer boundary. Holes, curved edges,
self-touching paths, automatic simplification, and automatic center-of-mass
repositioning are intentionally unsupported. Preprocess those shapes into
explicit convex ``CompoundPart`` values.

## Collision and query semantics

Broad-phase bounds enclose every transformed part. Point and ray queries test
parts individually, preserving empty concave regions. The narrow phase tests all
overlapping part pairs and returns the deepest deterministic one- or two-point
manifold for each pair of bodies. This keeps collision event identity at the
body level and bounds solver work, but it does not merge simultaneous manifolds
from separate parts.
