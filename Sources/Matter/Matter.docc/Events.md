# Typed Simulation Events

Observe successful simulation work without mutable callbacks.

## Subscribe before stepping

``Events`` creates independently cancellable ``MatterEventSubscription`` values.
Each stream yields the complete immutable ``SimulationResult`` returned by a
future successful ``Engine/stepWithEvents(ticks:)`` call. A ``Runner`` publishes
to the same subscriptions when it delegates fixed ticks to that engine.

```swift
let subscription = try await Events.subscribe(
    to: engine,
    bufferingPolicy: .bufferingNewest(2)
)

let observer = Task { @MainActor in
    for await result in subscription.stream {
        for event in result.collisionEvents where event.phase == .started {
            showImpact(event.collision)
        }
        updateScene(from: result.world)
    }
}
```

Subscriptions do not replay earlier work. Failed or cancelled steps do not yield
a result. Delivery uses `AsyncStream`, so consumers choose their own actor and no
simulation callback executes while the Engine actor is mutating its world.

## Backpressure and lifetime

``MatterEventBufferingPolicy/bufferingNewest(_:)`` is the default and is suitable
for rendering, where a stale frame should be discarded. Use
``MatterEventBufferingPolicy/bufferingOldest(_:)`` when the earliest pending
result is important, or ``MatterEventBufferingPolicy/unbounded`` only when the
consumer is guaranteed to keep pace.

Call ``MatterEventSubscription/cancel()`` to finish one stream. Cancellation is
idempotent and does not cancel Engine work. ``Events/removeAll(from:)`` finishes
every current subscription while leaving the world and future subscriptions
untouched.
