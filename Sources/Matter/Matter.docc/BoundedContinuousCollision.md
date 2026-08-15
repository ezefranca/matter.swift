# Bound Fast Motion with Adaptive Substeps

Make tunneling limits explicit while preserving deterministic Metal and CPU behavior.

## Opt into bounded motion

Matter performs one discrete integration and solve pass per fixed tick by
default. Enable adaptive substeps when fast bodies could cross a collider
between those samples:

```swift
let engine = try Engine(
    gravity: .zero,
    fixedTimeStep: 1.0 / 60.0,
    continuousCollisionConfiguration: ContinuousCollisionConfiguration(
        maximumMotionPerSubstep: 0.5,
        maximumSubsteps: 32
    )
)
```

``ContinuousCollisionPlanner`` conservatively predicts each awake dynamic
body's translation from current and accelerated velocity. It also adds angular
surface motion using angular velocity, torque, and a radius enclosing the
current bounds. The largest prediction determines a stable substep count.

Every selected substep performs integration, constraint solving, collision
detection, response, warm starting, and lifecycle tracking. Accumulated force
and torque are restored between intermediate integration passes and consumed
only after the last pass, so substepping does not reduce a force's fixed-tick
impulse.

## Interpret the bound

``ContinuousCollisionPlan`` records the chosen ``ContinuousCollisionPlan/substepCount``,
``ContinuousCollisionPlan/substepTime``, conservative
``ContinuousCollisionPlan/maximumPredictedMotion``, and whether the configured
cap was reached. Plans appear in fixed-tick order on
``SimulationResult/continuousCollisionPlans`` and ``RunnerUpdate/continuousCollisionPlans``.

When ``ContinuousCollisionPlan/isClamped`` is `false`, no individual body's
predicted surface motion exceeds ``ContinuousCollisionConfiguration/maximumMotionPerSubstep``.
Two bodies can close at up to twice that distance. Select a bound no larger than
half the thinnest collision interval that two moving bodies must not cross.

When `isClamped` is `true`, the plan still runs exactly
``ContinuousCollisionConfiguration/maximumSubsteps`` passes, but it reports that
the requested bound could not be honored. Clients can log the plan, raise the
cap, reduce the fixed time step, or limit extreme velocities instead of relying
on a hidden heuristic.

This is deterministic bounded discrete detection, not an analytic
time-of-impact solver. It supports every existing circle, polygon, compound,
constraint, sensor, and filter path without introducing shape-specific
continuous-collision behavior.

## Match the CPU reference path

Pass the same configuration to
``ReferencePhysics/stepWithEvents(world:collisionTracker:collisionSolverState:sleepingState:gravity:timeStep:solver:constraintSolver:sleeping:continuousCollision:)``.
The returned plan and simulation phases match the production engine, with only
the documented CPU-versus-Metal floating-point tolerance separating results.
