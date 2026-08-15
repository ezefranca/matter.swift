# Pointer Interaction

Drag bodies from mouse, touch, Pencil, or indirect-pointer coordinates without
coupling Matter to a user-interface framework.

## Create an interaction value

``MouseConstraint`` is a `Sendable`, value-semantic controller. A press queries
exact body geometry, ignores static bodies by default, and chooses the last
eligible body in stable world insertion order. The touched point is converted
to a body-local anchor so rotated bodies remain attached where the user grabbed
them.

```swift
var world = World()
_ = try world.add(Bodies.circle(at: .zero, radius: 24))
var mouse = try MouseConstraint()

try mouse.press(at: Vector(x: 4, y: 8), in: &world)
try mouse.move(to: Vector(x: 40, y: 30), in: &world)
mouse.release(in: &world)
```

The transient constraint uses the configured stiffness, damping, and angular
stiffness. Use ``MouseConstraintConfiguration/collisionFilter`` to select only
specific body categories, and opt into fixed-body selection explicitly with
``MouseConstraintConfiguration/includesStaticBodies``.

## Coordinate adapters

Matter and P5 remain independently importable and neither target depends on the
other. Their native integration point is Core Graphics: ``Vector/init(_:)``
accepts the `CGPoint` exposed by `P5PointerEvent.location`.

```swift
import Matter
import P5

func pointerPressed(_ event: P5PointerEvent, world: inout World) throws {
    try mouse.press(at: Vector(event.location), in: &world)
}
```

P5 reports top-left-origin canvas points and Matter uses the coordinates the
client supplies, so no implicit axis flip or display-scale conversion occurs.
Use the same transform for drawing and hit testing when the physics world does
not map one-to-one to the canvas.

## Actor-owned worlds

``Engine/updateWorld(_:)`` returns a `Sendable` result from a transactional
mutation. Return the updated controller to keep local interaction state in sync
with the actor-owned world:

```swift
mouse = try await engine.updateWorld { world in
    var updated = mouse
    try updated.move(to: point, in: &world)
    return updated
}
```

If the closure throws, the engine leaves its world unchanged. Releasing is
idempotent if another operation already removed the transient constraint.
