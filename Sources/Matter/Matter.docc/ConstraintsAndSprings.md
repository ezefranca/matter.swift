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
