# Collision Detection

Inspect broad-phase candidates and exact contacts without mutating a world.

## Query a snapshot

``CollisionDetector`` operates entirely on `Sendable` value snapshots. Its
adaptive sweep caches every ``Body/bounds`` once, chooses the widest world axis,
rejects separated intervals, and then applies both bodies'
``CollisionFilter`` values before the narrow phase.

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

## Measure broad-phase work

Call ``SweepAndPruneBroadPhase/query(in:)`` directly when diagnostics or
performance regression data are needed:

```swift
let result = SweepAndPruneBroadPhase.query(in: world)
print(result.metrics.axis)
print(result.metrics.primaryAxisTests, result.metrics.candidateCount)
```

``BroadPhaseResult`` contains the same canonical pairs returned by
``CollisionDetector/potentialPairs(in:)`` plus ``BroadPhaseMetrics``. The
counters measure primary-axis comparisons, full bounds tests, filter tests, and
emitted candidates without timing noise.

After sorting, separated horizontal or vertical sequences require exactly
`bodyCount - 1` primary-axis tests. A fully overlapping world emits
`bodyCount * (bodyCount - 1) / 2` pairs and necessarily performs that much work;
no exact broad phase can avoid the size of its output. The benchmark suite locks
both cases at 2,048 sparse bodies and 128 dense bodies, and compares 300 seeded
random bodies against an exhaustive oracle.
