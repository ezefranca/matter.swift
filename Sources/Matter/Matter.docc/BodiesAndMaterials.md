# Bodies, Shapes, and Materials

Build validated value-semantic physics bodies with stable world-owned identity.

## Create collision geometry

``Bodies`` provides circle, rectangle, regular-polygon, trapezoid, and convex
vertex factories. Factory coordinates are body centers; polygon vertices are
local to that center.

```swift
var world = World()

let ball = try world.add(
    Bodies.circle(at: Vector(x: 40, y: 20), radius: 8, mass: 2)
)
let ground = try world.add(
    Bodies.rectangle(
        at: Vector(x: 160, y: 300),
        width: 320,
        height: 24,
        isStatic: true
    )
)
```

``BodyShape/area``, ``BodyShape/localVertices``, and
``BodyShape/inertia(forMass:)`` expose deterministic geometry calculations.
``Body/vertices`` applies the body's current rotation and translation, while
``Body/bounds`` supplies an updated ``Bounds`` for broad-phase queries.

Vertex polygons must be finite, nondegenerate, and strictly convex. Concave and
compound decomposition is a separate explicit operation; the vertex factory
never silently changes input topology.

## Configure physical behavior

Use ``BodyDefinition`` directly when a body needs material, filtering, sensor,
or metadata options:

```swift
let bouncer = try BodyDefinition(
    shape: .circle(radius: 12),
    position: Vector(x: 80, y: 20),
    mass: 3,
    isSensor: false,
    label: "Bouncer",
    metadata: ["kind": "player"],
    material: BodyMaterial(
        restitution: 0.9,
        friction: 0.05,
        staticFriction: 0.1,
        airFriction: 0.01,
        slop: 0.02
    ),
    collisionFilter: CollisionFilter(category: 0b10, mask: 0b101)
)
```

``Body/mass``, ``Body/area``, ``Body/density``, and ``Body/inertia`` remain
finite serialized values. Static bodies retain these values for inspection but
report zero inverse mass and inverse inertia.

Equal nonzero collision groups override masks: positive groups always collide,
and negative groups never collide. Otherwise, both category-to-mask tests must
pass. A sensor participates in collision detection and events but receives no
physical collision impulse.

## Apply motion

Force at the center changes linear velocity. Force at a world-space point also
adds its moment around ``Body/centerOfMass``. Torque changes angular velocity.

```swift
try world.applyForce(Vector(x: 20, y: 0), to: ball)
try world.applyForce(
    Vector(x: 0, y: -10),
    at: Vector(x: 48, y: 20),
    to: ball
)
try world.applyTorque(4, to: ball)
```

Use ``World/updateBody(withID:_:)`` for a batch of synchronous value mutations,
including position, angle, linear velocity, and angular velocity setters. World
ordering and identifiers do not change during mutation.

The CPU reference integrator and Metal kernel both use semi-implicit Euler
integration for linear and angular motion, followed by configured air damping.
They clear force and torque after every tick. The default material has zero drag
to preserve the package's original integration behavior; opt into damping by
setting `airFriction`.
