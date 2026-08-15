# Constraints and Springs

Connect fixed world points and body-local anchors with deterministic distance
constraints. Constraints are value snapshots owned by a ``World`` and solved on
the CPU after each Metal integration pass.

## Pin a body

Use ``Constraints/pin(_:localAnchor:to:length:stiffness:damping:angularStiffness:maximumImpulse:)``
to attach a body-local point to the world:

```swift
let pendulum = try world.add(
    Bodies.circle(at: Vector(x: 160, y: 180), radius: 16)
)
let pivot = try world.addConstraint(
    Constraints.pin(
        pendulum,
        to: Vector(x: 160, y: 40),
        length: 140,
        stiffness: 1,
        damping: 0.05
    )
)
```

Omit `length` to capture the current distance between anchors. A zero length is
valid. Fixed and local anchor vectors must be finite.

## Connect bodies

``Constraints/distance(between:localAnchor:and:localAnchor:length:stiffness:damping:angularStiffness:maximumImpulse:)``
supports independent local anchors on two bodies. ``Constraints/spring(between:and:length:stiffness:damping:maximumImpulse:)``
provides compliant defaults for a centered spring.

```swift
let joint = try world.addConstraint(
    Constraints.distance(
        between: first,
        localAnchor: Vector(x: 10, y: 0),
        and: second,
        localAnchor: Vector(x: -10, y: 0),
        stiffness: 0.8,
        damping: 0.15,
        angularStiffness: 0.1
    )
)
```

`stiffness`, `damping`, and `angularStiffness` use the closed range `0...1`.
Angular stiffness preserves the relative orientation captured when the
constraint is added, or the captured body orientation for a world pin.

## Configure solving and breakage

``ConstraintSolver`` uses deterministic sequential velocity and position
passes. Configure their counts with ``ConstraintSolverConfiguration``. An
``Engine`` validates and retains one configuration for every fixed tick, while
``ReferencePhysics`` uses the same solver for CPU reference calculations.

Set `maximumImpulse` to remove a constraint before applying a correction larger
than the supplied limit. ``SimulationResult/brokenConstraints`` and
``RunnerUpdate/brokenConstraints`` report removed identifiers in stable order.
The estimate uses the fixed time step, positional error, angular error, inverse
mass, and configured stiffness; it is deterministic but is not a force sensor.

Removing a body automatically removes every constraint that references it.
Removing a constraint also cleans its composite membership.

## Lock rotation and drive motors

``Constraints/rotationalLock(between:and:length:stiffness:damping:)`` creates a
distance joint with full angular stiffness, preserving the bodies' captured
relative angle. For a driven pivot, use
``Constraints/motor(_:pivot:targetSpeed:maximumTorque:damping:)``:

```swift
let windmillJoint = try world.addConstraint(
    Constraints.motor(
        windmill,
        pivot: Vector(x: 160, y: 120),
        targetSpeed: 1.5,
        maximumTorque: 20
    )
)
```

Motor speed is the second endpoint's angular velocity relative to the first.
Positive speed follows Matter's clockwise-angle convention. When supplied,
`maximumTorque` caps total angular impulse per fixed tick; the solver divides
that allowance across velocity iterations so iteration tuning does not increase
available torque. Omit the cap for a servo-like motor that reaches its target in
one velocity pass.

## Build larger assemblies

Use the factory helpers to produce deterministic arrays of validated
``ConstraintDefinition`` values:

- ``Constraints/chain(_:length:stiffness:damping:angularStiffness:maximumImpulse:)``
  connects adjacent body identifiers.
- ``Constraints/pendulum(_:pivot:localAnchor:length:stiffness:damping:maximumImpulse:)``
  configures a world pin with pendulum defaults.
- ``Constraints/bridge(_:from:to:segmentLength:stiffness:damping:maximumImpulse:)``
  adds endpoint pins around a chain.
- ``Constraints/mesh(_:length:stiffness:damping:crossBrace:maximumImpulse:)``
  connects rectangular body-ID grids horizontally and vertically, with optional
  diagonal cross braces.
- ``Constraints/softBody(_:length:stiffness:damping:maximumImpulse:)`` creates a
  compliant, cross-braced grid.

Commit the resulting assembly atomically with ``World/addConstraints(_:to:)``
or ``Engine/addConstraints(_:to:)``:

```swift
let clothDefinitions = try Constraints.mesh(
    bodyGrid,
    stiffness: 0.6,
    damping: 0.12,
    crossBrace: true
)
let clothConstraints = try world.addConstraints(
    clothDefinitions,
    to: clothComposite
)
```

Meshes require a nonempty rectangular grid. A one-row or one-column mesh is
valid; a chain or bridge requires at least two bodies.
