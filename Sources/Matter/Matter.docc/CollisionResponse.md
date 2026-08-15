# Collision Response

Resolve contacts with deterministic impulses and explicit execution ownership.

## Configure the solver

``SolverConfiguration`` controls sequential velocity iterations, positional
iterations, the corrected fraction of penetration, and the speed below which
restitution is suppressed to prevent low-speed jitter.

```swift
let solver = SolverConfiguration(
    velocityIterations: 8,
    positionIterations: 3,
    positionCorrection: 0.8,
    restitutionVelocityThreshold: 1
)
```

Iteration counts must be positive. Correction must be finite and in `0...1`,
and the restitution threshold must be finite and nonnegative. Invalid tuning
throws ``MatterError/invalidSolverConfiguration`` before mutation begins.

## Resolve a value snapshot

Use ``CollisionSolver`` when integration and response need to be scheduled
separately:

```swift
let contacts = try CollisionSolver.resolve(
    world: &world,
    configuration: solver
)
```

## Persist and warm-start contacts

Reuse ``CollisionSolverState`` across fixed ticks to retain accumulated normal
and friction impulses:

```swift
var solverState = CollisionSolverState()

try ReferenceIntegrator.step(
    world: &world,
    gravity: Vector(x: 0, y: 9.81),
    timeStep: 1 / 60
)
let contacts = try CollisionSolver.resolve(
    world: &world,
    state: &solverState,
    configuration: .standard
)
```

Each ``CollisionContact`` carries a ``ContactFeatureID`` composed of selected
primitive-part indices and the stable contact index within that manifold. A
``ContactKey`` combines it with the canonical body pair. The solver applies the
previous tick's ``ContactImpulse`` before its sequential iterations, accumulates
new impulses with nonnegative normal and Coulomb-friction bounds, and removes
ended or sensor contacts.

``Engine`` owns this cache automatically and exposes an immutable
``Engine/solverStateSnapshot()`` for diagnostics. Replacing the engine world
clears it. Call ``CollisionSolverState/reset()`` when a manually managed state
will be reused with an unrelated world.

The returned collisions represent the state before positional correction.
Velocity passes apply normal impulses, restitution, geometric-mean static and
dynamic friction, and angular impulse at every contact point. Position passes
correct penetration beyond the larger body slop according to inverse mass.
Static and sleeping bodies contribute zero effective inverse mass and inertia.
Sensors are returned to the caller but never receive impulses or correction.

``ReferencePhysics/step(world:gravity:timeStep:solver:)`` combines the CPU
reference integrator and the same solver for deterministic tests and tooling.
Its stateful `stepWithEvents` overload additionally mirrors collision lifecycle,
warm-start caching, constraints, and island sleeping in one explicit CPU tick.

## Understand the production pipeline

``Engine`` integrates linear and angular body state using ``MetalBackend``.
After the GPU command completes, the actor runs ``CollisionDetector`` and
``CollisionSolver`` synchronously on its isolated world snapshot. Collision
detection and response are deliberately CPU-owned phases; they are not a
fallback selected after a Metal failure. Metal initialization or integration
failures remain visible as ``MetalBackendError`` values.

Call ``Engine/stepWithEvents(ticks:)`` when a client needs the complete
``SimulationResult``. It includes final-tick collisions and an ordered stream of
``CollisionEvent`` values accumulated across all requested ticks. A
``CollisionTracker`` classifies canonical pairs as ``CollisionPhase/started``,
``CollisionPhase/active``, or ``CollisionPhase/ended``; ended events retain the
last known manifold. The tracker is a standalone `Codable` value for custom
manual-step pipelines as well.

This release uses discrete detection. Fast bodies can tunnel when they cross an
entire collider within one fixed step; continuous collision detection remains a
separate capability rather than an implicit heuristic.
