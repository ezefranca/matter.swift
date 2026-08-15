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

The returned collisions represent the state before positional correction.
Velocity passes apply normal impulses, restitution, geometric-mean static and
dynamic friction, and angular impulse at every contact point. Position passes
correct penetration beyond the larger body slop according to inverse mass.
Static bodies contribute zero inverse mass and inertia. Sensors are returned to
the caller but never receive impulses or correction.

``ReferencePhysics/step(world:gravity:timeStep:solver:)`` combines the CPU
reference integrator and the same solver for deterministic tests and tooling.

## Understand the production pipeline

``Engine`` integrates linear and angular body state using ``MetalBackend``.
After the GPU command completes, the actor runs ``CollisionDetector`` and
``CollisionSolver`` synchronously on its isolated world snapshot. Collision
detection and response are deliberately CPU-owned phases; they are not a
fallback selected after a Metal failure. Metal initialization or integration
failures remain visible as ``MetalBackendError`` values.

This release uses discrete detection. Fast bodies can tunnel when they cross an
entire collider within one fixed step; continuous collision detection remains a
separate capability rather than an implicit heuristic.
