# Force Behaviors

Apply deterministic inverse-square attraction or repulsion from a fixed point or
a moving body.

## Attract bodies

An ``Attractor`` calculates the familiar `G × sourceMass × targetMass / d²`
force used by Nature of Code attraction examples. Its distance limits bound the
denominator near and far from the source, and ``Attractor/maximumForce`` can add
an absolute cap.

```swift
let attractor = try Attractor(
    source: .point(position: Vector(x: 320, y: 240), mass: 20),
    strength: 0.4,
    minimumDistance: 5,
    maximumDistance: 25
)

try attractor.apply(in: &world)
try ReferencePhysics.step(
    world: &world,
    gravity: .zero,
    timeStep: 1 / 60
)
```

Positive strength attracts and negative strength repels. Zero is permitted for
deterministic enable/disable logic. Static bodies, filtered categories, the
source body itself, and bodies exactly coincident with the source receive no
application.

## Follow a moving source

Use ``AttractionSource/body(_:)`` to resolve a body's current position and mass
on every call:

```swift
let field = try Attractor(source: .body(sunID), strength: 1)
let applications = try await engine.apply(field, to: planetIDs)
```

The force is deliberately one-way. This matches a fixed attractor and avoids an
implicit double application in all-pairs simulations. Apply a corresponding
field in the other direction when reciprocal attraction is required.

``Attractor/applications(to:in:)`` exposes immutable force values for debugging
and tests without changing the world. Explicit target identifiers must be
unique and valid; all validation finishes before ``Attractor/apply(to:in:)``
mutates the first body.
