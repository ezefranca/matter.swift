# ``Matter``

A Metal-first, native Swift foundation inspired conceptually by Matter.js.

## Overview

Matter owns bodies in a ``World`` and exposes a concurrency-safe ``Engine`` for
fixed-timestep Metal simulation. It intentionally has no SpriteKit dependency
and does not silently replace GPU execution with CPU work.

Create geometry with ``Bodies``, add it to an engine, apply force, and await a
simulation tick:

```swift
let engine = try Engine(gravity: Vector(x: 0, y: 9.81))
let ball = try await engine.add(Bodies.circle(at: .zero, radius: 12))
try await engine.applyForce(Vector(x: 10, y: 0), to: ball)
let world = try await engine.step()
```

For reproducible reference calculations and tests only, use
``ReferenceIntegrator``. It is never used as a runtime fallback.

Matter is independently versioned. Compose it at the application layer with
[p5.swift](https://github.com/ezefranca/p5.swift) for visualization or
[ml5.swift](https://github.com/ezefranca/ml5.swift) for native machine learning;
none of the packages has a production dependency on another.

## Topics

### Essentials

- <doc:GettingStarted>
- ``Engine``
- ``World``
- ``Body``
- ``BodyDefinition``
- ``Bodies``
- ``BodyShape``
- ``CompoundPart``
- ``ConcaveDecomposer``
- ``BodyMaterial``
- ``CollisionFilter``
- ``Bounds``
- <doc:BodiesAndMaterials>
- <doc:CompoundBodies>

### World organization

- ``Composite``
- ``CompositeID``
- <doc:CompositesAndBatches>

### Constraints

- ``Constraint``
- ``ConstraintID``
- ``ConstraintAnchor``
- ``ConstraintDefinition``
- ``Constraints``
- ``ConstraintSolver``
- ``ConstraintSolverConfiguration``
- ``MouseConstraint``
- ``MouseConstraintConfiguration``
- <doc:ConstraintsAndSprings>
- <doc:PointerInteraction>

### Collision queries

- ``CollisionDetector``
- ``SweepAndPruneBroadPhase``
- ``BroadPhaseResult``
- ``BroadPhaseMetrics``
- ``BroadPhaseAxis``
- ``Collision``
- ``CollisionContact``
- ``ContactFeatureID``
- ``ContactKey``
- ``ContactImpulse``
- ``CollisionSolverState``
- ``BodyPair``
- ``CollisionSolver``
- ``SolverConfiguration``
- ``CollisionTracker``
- ``CollisionEvent``
- ``CollisionPhase``
- ``SimulationResult``
- ``Events``
- ``MatterEventSubscription``
- ``MatterEventBufferingPolicy``
- <doc:SimulationEvents>
- <doc:CollisionDetection>
- <doc:CollisionResponse>

### Sleeping and islands

- ``SleepingConfiguration``
- ``SleepingState``
- ``SleepingManager``
- ``SleepingPhase``
- ``SleepingEvent``
- ``SimulationIsland``
- ``IslandManager``
- <doc:SleepingAndIslands>

### Spatial queries

- ``WorldQuery``
- ``RaycastHit``
- <doc:SpatialQueries>

### Drawing adapters

- ``MatterDrawingAdapter``
- ``MatterDrawingCommand``
- ``MatterDrawingPrimitive``
- ``MatterDrawingSource``
- ``MatterDrawingLayer``
- ``MatterDrawingOptions``
- <doc:DrawingWithP5>

### Simulation

- ``Vector``
- ``Attractor``
- ``AttractionSource``
- ``ForceApplication``
- ``ReferenceIntegrator``
- ``ReferencePhysics``
- ``ContinuousCollisionConfiguration``
- ``ContinuousCollisionPlan``
- ``ContinuousCollisionPlanner``
- ``MatterExecutionPolicy``
- ``MatterExecutionStage``
- ``MatterExecutionBackend``
- ``MetalBackend``
- ``MetalBackendError``
- ``MetalBackendStatistics``
- ``Runner``
- ``RunnerUpdate``
- ``FixedStepAccumulator``
- ``FixedStepAdvance``
- <doc:RunningSimulation>
- <doc:ForceBehaviors>
- <doc:BoundedContinuousCollision>

### Design

- <doc:Architecture>
- <doc:MatterCompatibility>
