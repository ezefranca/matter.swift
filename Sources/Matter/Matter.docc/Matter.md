@Metadata {
  @DisplayName("Matter")
  @PageColor(green)
}

# Matter

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

## Topics

### Essentials

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
- ``Collision``
- ``CollisionContact``
- ``BodyPair``
- ``CollisionSolver``
- ``SolverConfiguration``
- ``CollisionTracker``
- ``CollisionEvent``
- ``CollisionPhase``
- ``SimulationResult``
- <doc:CollisionDetection>
- <doc:CollisionResponse>

### Spatial queries

- ``WorldQuery``
- ``RaycastHit``
- <doc:SpatialQueries>

### Simulation

- ``Vector``
- ``Attractor``
- ``AttractionSource``
- ``ForceApplication``
- ``ReferenceIntegrator``
- ``ReferencePhysics``
- ``MetalBackend``
- ``MetalBackendError``
- ``Runner``
- ``RunnerUpdate``
- ``FixedStepAccumulator``
- ``FixedStepAdvance``
- <doc:RunningSimulation>
- <doc:ForceBehaviors>

### Architecture

- <doc:Architecture>
