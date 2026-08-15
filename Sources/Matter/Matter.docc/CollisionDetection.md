# Collision Detection

Inspect broad-phase candidates and exact contacts without mutating a world.

## Query a snapshot

``CollisionDetector`` operates entirely on `Sendable` value snapshots. Its
x-axis sweep rejects bodies whose ``Body/bounds`` cannot overlap, then applies
both bodies' ``CollisionFilter`` values before the narrow phase.

```swift
let candidates = CollisionDetector.potentialPairs(in: world)
let collisions = CollisionDetector.collisions(in: world)

for collision in collisions {
    print(collision.pair, collision.normal, collision.penetration)
}
```

``BodyPair`` stores the lower ID first, so pair equality, serialization, and
result ordering do not depend on insertion into an intermediate data structure.
Two equal IDs do not form a pair.

## Interpret a manifold

Every ``Collision`` normal points from ``BodyPair/first`` toward
``BodyPair/second``. ``Collision/penetration`` is zero when shapes touch and
positive when they overlap. Its ``Collision/contacts`` contain one or two
deterministically ordered world-space ``CollisionContact`` values.

Circle-circle detection uses the exact radial distance. Circle-polygon and
polygon-polygon detection use the separating-axis theorem. Polygon manifolds
come from the clipped convex intersection, while curved contacts use opposing
support points. Input vertex polygons must already be convex, as described in
<doc:BodiesAndMaterials>.

Sensors participate in both phases and return collisions whose
``Collision/isSensor`` is `true`; the response solver must not apply impulses to
those pairs. Static bodies also remain queryable. Filtering follows Matter's
group override and bidirectional category-mask rules.

The detector is a CPU query API, not a fallback for ``MetalBackend``. It has no
hidden mutable cache and returns identical ordered results for identical world
snapshots.
