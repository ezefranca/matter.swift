# Spatial Queries

Inspect an immutable ``World`` snapshot with exact point tests, broad region
queries, and finite ray segments. Queries do not mutate bodies or depend on a
Metal device.

## Find bodies at a point

``WorldQuery/bodies(at:in:)`` checks circles and convex polygons against their
current world-space geometry. Results preserve the world's stable body order.

```swift
let point = Vector(x: 20, y: 10)
let bodies = try WorldQuery.bodies(at: point, in: world)
```

The point must be finite. Boundaries count as contained, and an invalid point
throws ``MatterError/invalidVector``.

## Search a region

Use ``WorldQuery/bodies(in:world:)`` when overlapping axis-aligned bounds are
sufficient:

```swift
let viewport = Bounds(
    minimum: Vector(x: 0, y: 0),
    maximum: Vector(x: 320, y: 240)
)
let visibleBodies = WorldQuery.bodies(in: viewport, world: world)
```

This is an AABB query. A body's precise shape may not occupy every point in its
bounds, so refine the result when an exact geometric test is required.

## Cast a finite ray

``WorldQuery/raycast(from:to:in:)`` returns the first surface intersection for
each body. Hits order by distance, then by ``BodyID``, making ties deterministic.

```swift
let hits = try WorldQuery.raycast(
    from: Vector(x: 0, y: 120),
    to: Vector(x: 320, y: 120),
    in: world
)

if let nearest = hits.first {
    print(nearest.body, nearest.point, nearest.normal)
}
```

``RaycastHit/fraction`` is in `0...1`, and ``RaycastHit/normal`` faces against
the ray direction. A segment that starts inside a body reports a zero-distance
hit. Equal or nonfinite endpoints throw ``MatterError/invalidRay``.
