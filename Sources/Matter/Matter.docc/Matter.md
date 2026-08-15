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
- ``BodyMaterial``
- ``CollisionFilter``
- ``Bounds``
- <doc:BodiesAndMaterials>

### Collision queries

- ``CollisionDetector``
- ``Collision``
- ``CollisionContact``
- ``BodyPair``
- <doc:CollisionDetection>

### Simulation

- ``Vector``
- ``ReferenceIntegrator``
- ``MetalBackend``
- ``MetalBackendError``

### Architecture

- <doc:Architecture>
