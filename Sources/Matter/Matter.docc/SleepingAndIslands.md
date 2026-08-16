# Sleeping and Simulation Islands

Suspend quiet connected bodies without changing deterministic fixed-step behavior.

## Enable sleeping explicitly

Automatic sleeping is opt-in so an existing engine continues integrating every
dynamic body. Pass ``SleepingConfiguration/standard`` or custom thresholds to
``Engine``:

```swift
let engine = try Engine(
    gravity: Vector(x: 0, y: 9.81),
    sleepingConfiguration: .standard
)
```

An island must remain below both velocity thresholds for
``SleepingConfiguration/minimumQuietTime`` before all of its bodies sleep
together. Sleeping bodies expose ``Body/isSleeping``, retain their shape and
transform, and report zero effective inverse mass and inertia. Integration,
constraints, and contacts therefore leave them fixed until they wake.

Use ``Body/setSleeping(_:)`` for explicit control. Applying force or torque, or
setting position, angle, or velocity, wakes that body immediately. Before a
solve, wakefulness propagates to every connected sleeping body so a constraint
or nonsensor collision never leaves part of an active island asleep.
An explicit wake resets accumulated quiet time before sleep can begin again.

## Inspect deterministic islands

``IslandManager`` connects dynamic bodies through body-to-body constraints and
nonsensor collisions. Static bodies participate in response but do not merge
otherwise independent components through a shared floor or wall. Sensors do
not create physical connections either.

```swift
let collisions = CollisionDetector.collisions(in: world)
let islands = IslandManager.islands(in: world, collisions: collisions)

for island in islands {
    inspect(island.identifier, bodies: island.bodyIDs)
}
```

Both islands and their ``SimulationIsland/bodyIDs`` use ascending stable body
identifiers. This makes diagnostics and serialized state independent of hash
table or task scheduling order.

## Observe transitions

``Engine`` retains a ``SleepingState`` alongside its warm-start contact cache.
``Engine/sleepingStateSnapshot()`` exposes accumulated quiet times for
diagnostics, while ``SimulationResult/sleepingEvents`` reports ordered
``SleepingEvent`` values for every requested tick. ``RunnerUpdate`` forwards
the same event stream.

For a custom CPU pipeline, ``ReferencePhysics/stepWithEvents(world:collisionTracker:collisionSolverState:sleepingState:gravity:timeStep:solver:constraintSolver:sleeping:continuousCollision:)``
accepts all persistent state explicitly and returns the same result shape as a
single engine tick. Lower-level schedulers can instead call
``SleepingManager/prepareForStep(world:collisions:)`` before work and
``SleepingManager/update(world:state:collisions:timeStep:configuration:)``
after response.

Disabling sleeping wakes any explicitly sleeping bodies before integration and
clears accumulated quiet times. Resetting an engine clears its sleeping state.
