# Your First Matter World

Build and step a deterministic physics world through an actor-owned engine.

```swift
import Matter

let engine = try Engine(gravity: Vector(x: 0, y: 9.81))
let floor = try await engine.add(
    Bodies.rectangle(at: Vector(x: 0, y: 10), width: 40, height: 1, isStatic: true)
)
let ball = try await engine.add(
    Bodies.circle(at: Vector(x: 0, y: -10), radius: 1, mass: 1)
)
try await engine.applyForce(Vector(x: 2, y: 0), to: ball)
let result = try await engine.step()
```

Retain identifiers, not mutable body references. ``Engine`` serializes mutation;
``SimulationResult`` and ``World`` snapshots are immutable `Sendable` values that
can cross to a UI actor safely.

Matter requires Metal for production integration. Check
``MetalBackend/isAvailable`` before presenting a Metal-dependent experience and
handle ``MetalBackendError``. ``ReferencePhysics`` is a deterministic oracle for
tests and tooling, not a silent runtime fallback.

Use <doc:RunningSimulation> for fixed-step frame integration,
<doc:CollisionResponse> for solver behavior, and <doc:MatterCompatibility> when
porting Matter.js code.
