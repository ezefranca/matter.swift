# Running a Simulation

Convert variable wall-clock updates into bounded deterministic physics ticks.

## Accumulate time explicitly

``FixedStepAccumulator`` is a `Codable`, `Sendable` value that performs no
simulation work. It converts elapsed seconds into a ``FixedStepAdvance``:

```swift
var timing = try FixedStepAccumulator(
    fixedTimeStep: 1.0 / 60.0,
    maximumTicksPerAdvance: 5
)

let advance = try timing.advance(by: elapsedSeconds)
if advance.tickCount > 0 {
    let result = try await engine.stepWithEvents(ticks: advance.tickCount)
}
render(interpolationAlpha: advance.interpolationAlpha)
```

The accumulator caps accepted time to one update's maximum tick count. It
reports discarded time through ``FixedStepAdvance/droppedTime`` and maintains
``FixedStepAccumulator/totalDroppedTime`` for diagnostics. This prevents an
unbounded catch-up spiral after suspension or debugger pauses.

Negative and nonfinite elapsed values throw ``MatterError/invalidElapsedTime``.
The fixed step must be finite and positive, and the per-advance tick limit must
be positive. Pausing validates but ignores elapsed time and preserves the
existing interpolation remainder. Reset can either preserve or clear pause
state.

## Use the actor runner

``Runner`` owns timing around an existing ``Engine``:

```swift
let runner = try Runner(engine: engine, maximumTicksPerAdvance: 5)

let update = try await runner.advance(by: elapsedSeconds)
draw(update.world, interpolationAlpha: update.interpolationAlpha)
```

``RunnerUpdate`` combines the current immutable world, tick count,
interpolation alpha, dropped time, final-tick collisions, every collision event,
the identifiers of constraints broken during the update, and every sleeping
transition. A zero-tick update snapshots the engine without submitting Metal
work.

When adaptive motion substeps are enabled, both ``SimulationResult`` and
``RunnerUpdate`` include one ``ContinuousCollisionPlan`` per emitted fixed tick.
The runner's `tickCount` remains a count of fixed ticks, not internal solve
passes.

``Runner/pause()``, ``Runner/resume()``, and ``Runner/resetTiming(keepingPauseState:)``
control time without changing the world. ``Runner/reset(to:)`` also replaces the
world and clears collision lifecycle state. Cancellation is checked before
elapsed time is consumed and is forwarded through Metal-backed engine steps.
