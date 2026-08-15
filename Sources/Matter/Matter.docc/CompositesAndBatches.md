# Composites and Batch Mutations

Organize a world's bodies without creating a second owner for physics state.
``Composite`` values contain stable ``BodyID`` references and an optional parent
``CompositeID``; the ``World`` remains the only owner of each ``Body``.

## Build a hierarchy

```swift
var world = World()
let scene = try world.addComposite(label: "Scene")
let flock = try world.addComposite(
    label: "Flock",
    metadata: ["chapter": "6"],
    parent: scene
)

let birds = try world.add(
    [
        Bodies.circle(at: Vector(x: 80, y: 100), radius: 8),
        Bodies.circle(at: Vector(x: 120, y: 100), radius: 8),
    ],
    to: flock
)
```

``World/childComposites(of:)`` returns roots when its argument is `nil` and
direct children otherwise. ``World/bodies(in:includingDescendants:)`` includes
descendants by default and always returns bodies in stable world order.

A body belongs directly to at most one composite. Calling
``World/assignBody(_:to:)`` moves it from any previous owner, while
``World/unassignBody(_:)`` leaves the body in the world without a group.
Reparenting with ``World/reparentComposite(_:to:)`` rejects self-parenting and
ancestor cycles.

## Remove groups explicitly

Removing a composite removes its entire descendant hierarchy. Bodies remain in
the world unless `removeBodies` is `true`:

```swift
let removedGroups = try world.removeComposite(
    withID: scene,
    removeBodies: false
)
```

The returned composites follow stable world insertion order. Direct body
removal always cleans composite membership.

## Commit batches atomically

Array-based add, update, and remove operations validate every identifier and
input before changing the world. A throwing update closure leaves every body at
its original value.

```swift
try world.updateBodies(withIDs: birds) { body in
    try body.translate(by: Vector(x: 10, y: 0))
}
```

When an ``Engine`` owns the world, its matching methods perform the whole batch
in one actor hop. Use ``Engine/updateWorld(_:)`` when one transaction needs to
combine body, composite, and other world operations:

```swift
try await engine.updateWorld { world in
    try world.updateBodies(withIDs: birds) { body in
        try body.setVelocity(Vector(x: 2, y: 0))
    }
    try world.assignBody(birds[0], to: flock)
}
```
