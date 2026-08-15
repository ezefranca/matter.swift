/// The timing decision produced by one fixed-step accumulator advance.
@frozen
public struct FixedStepAdvance: Sendable, Hashable, Codable {
    /// The number of complete fixed ticks ready to simulate.
    public let tickCount: Int

    /// Remaining fractional progress toward the next tick, in `0..<1`.
    public let interpolationAlpha: Float

    /// Elapsed time discarded by this advance to cap catch-up work.
    public let droppedTime: Float

    init(tickCount: Int, interpolationAlpha: Float, droppedTime: Float) {
        self.tickCount = tickCount
        self.interpolationAlpha = interpolationAlpha
        self.droppedTime = droppedTime
    }
}

/// A deterministic, value-semantic fixed-step time accumulator.
@frozen
public struct FixedStepAccumulator: Sendable, Hashable, Codable {
    /// The finite, positive duration of every simulation tick.
    public let fixedTimeStep: Float

    /// The maximum ticks emitted by one ``advance(by:)`` call.
    public let maximumTicksPerAdvance: Int

    /// Whether advances currently preserve time without accumulating it.
    public private(set) var isPaused: Bool

    /// Total elapsed time dropped by the catch-up cap since the last reset.
    public private(set) var totalDroppedTime: Float

    private var remainder: Float

    /// Creates a fixed-step accumulator with a bounded catch-up budget.
    ///
    /// - Throws: ``MatterError/invalidTimeStep`` or
    ///   ``MatterError/invalidMaximumTicks`` for invalid configuration.
    public init(fixedTimeStep: Float, maximumTicksPerAdvance: Int = 5) throws {
        guard fixedTimeStep.isFinite, fixedTimeStep > 0 else {
            throw MatterError.invalidTimeStep
        }
        guard maximumTicksPerAdvance > 0 else {
            throw MatterError.invalidMaximumTicks
        }
        self.fixedTimeStep = fixedTimeStep
        self.maximumTicksPerAdvance = maximumTicksPerAdvance
        self.isPaused = false
        self.totalDroppedTime = 0
        self.remainder = 0
    }

    /// Fractional progress available for render interpolation, in `0..<1`.
    public var interpolationAlpha: Float {
        remainder / fixedTimeStep
    }

    /// Accumulates elapsed time and returns bounded fixed-tick work.
    ///
    /// Paused accumulators validate but otherwise ignore elapsed time.
    ///
    /// - Throws: ``MatterError/invalidElapsedTime`` when elapsed time is
    ///   negative or nonfinite.
    public mutating func advance(by elapsedTime: Float) throws -> FixedStepAdvance {
        guard elapsedTime.isFinite, elapsedTime >= 0 else {
            throw MatterError.invalidElapsedTime
        }
        guard !isPaused else {
            return FixedStepAdvance(
                tickCount: 0,
                interpolationAlpha: interpolationAlpha,
                droppedTime: 0
            )
        }

        let available = remainder + elapsedTime
        let maximumTime = fixedTimeStep * Float(maximumTicksPerAdvance)
        let acceptedTime = min(available, maximumTime)
        let droppedTime = max(available - maximumTime, 0)
        let tickCount = min(Int(acceptedTime / fixedTimeStep), maximumTicksPerAdvance)
        remainder = acceptedTime - Float(tickCount) * fixedTimeStep
        totalDroppedTime += droppedTime
        return FixedStepAdvance(
            tickCount: tickCount,
            interpolationAlpha: interpolationAlpha,
            droppedTime: droppedTime
        )
    }

    /// Stops time accumulation until ``resume()`` is called.
    public mutating func pause() {
        isPaused = true
    }

    /// Resumes time accumulation without changing the existing remainder.
    public mutating func resume() {
        isPaused = false
    }

    /// Clears interpolation and dropped-time state.
    ///
    /// - Parameter keepingPauseState: Whether to preserve ``isPaused``.
    public mutating func reset(keepingPauseState: Bool = false) {
        remainder = 0
        totalDroppedTime = 0
        if !keepingPauseState {
            isPaused = false
        }
    }
}

/// The immutable result of advancing a ``Runner`` with wall-clock time.
@frozen
public struct RunnerUpdate: Sendable, Hashable, Codable {
    /// The current engine world after any emitted ticks.
    public let world: World

    /// The number of fixed ticks performed by this update.
    public let tickCount: Int

    /// Remaining fractional progress for client-side render interpolation.
    public let interpolationAlpha: Float

    /// Elapsed time discarded by this update's catch-up cap.
    public let droppedTime: Float

    /// Collisions detected in the final emitted tick, or none for zero ticks.
    public let collisions: [Collision]

    /// Collision lifecycle events accumulated across emitted ticks.
    public let collisionEvents: [CollisionEvent]

    init(world: World, timing: FixedStepAdvance, simulation: SimulationResult?) {
        self.world = world
        self.tickCount = timing.tickCount
        self.interpolationAlpha = timing.interpolationAlpha
        self.droppedTime = timing.droppedTime
        self.collisions = simulation?.collisions ?? []
        self.collisionEvents = simulation?.collisionEvents ?? []
    }
}

/// Actor-isolated wall-clock scheduling for a fixed-step ``Engine``.
///
/// A runner caps catch-up work, supports pause and reset, and forwards engine
/// cancellation and Metal failures without hiding them.
public actor Runner {
    private let engine: Engine
    private var accumulator: FixedStepAccumulator

    /// Creates a runner whose step duration is read from its engine.
    ///
    /// - Throws: ``MatterError/invalidMaximumTicks`` for a nonpositive cap.
    public init(engine: Engine, maximumTicksPerAdvance: Int = 5) throws {
        self.engine = engine
        self.accumulator = try FixedStepAccumulator(
            fixedTimeStep: engine.fixedTimeStep,
            maximumTicksPerAdvance: maximumTicksPerAdvance
        )
    }

    /// Returns a value snapshot of current timing state.
    public func timingSnapshot() -> FixedStepAccumulator {
        accumulator
    }

    /// Advances wall-clock time and runs the resulting bounded engine ticks.
    ///
    /// - Throws: Invalid elapsed time, cancellation, or an engine Metal failure.
    public func advance(by elapsedTime: Float) async throws -> RunnerUpdate {
        try Task.checkCancellation()
        let timing = try accumulator.advance(by: elapsedTime)
        guard timing.tickCount > 0 else {
            return RunnerUpdate(
                world: await engine.snapshot(),
                timing: timing,
                simulation: nil
            )
        }

        let simulation = try await engine.stepWithEvents(ticks: timing.tickCount)
        return RunnerUpdate(world: simulation.world, timing: timing, simulation: simulation)
    }

    /// Pauses elapsed-time accumulation.
    public func pause() {
        accumulator.pause()
    }

    /// Resumes elapsed-time accumulation with the preserved remainder.
    public func resume() {
        accumulator.resume()
    }

    /// Clears timing state without changing the engine world.
    public func resetTiming(keepingPauseState: Bool = false) {
        accumulator.reset(keepingPauseState: keepingPauseState)
    }

    /// Replaces the engine world and clears timing and collision lifecycle state.
    public func reset(to world: World = .init()) async {
        accumulator.reset()
        await engine.reset(to: world)
    }
}
