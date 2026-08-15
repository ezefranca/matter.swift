import Testing

@testable import Matter

@Suite("Matter fixed-step runner")
struct MatterRunnerTests {
    @Test("Accumulator validates configuration and elapsed time")
    func accumulatorValidation() throws {
        #expect(throws: MatterError.invalidTimeStep) {
            try FixedStepAccumulator(fixedTimeStep: 0)
        }
        #expect(throws: MatterError.invalidTimeStep) {
            try FixedStepAccumulator(fixedTimeStep: -.infinity)
        }
        #expect(throws: MatterError.invalidMaximumTicks) {
            try FixedStepAccumulator(fixedTimeStep: 0.1, maximumTicksPerAdvance: 0)
        }

        var accumulator = try FixedStepAccumulator(fixedTimeStep: 0.1)
        #expect(throws: MatterError.invalidElapsedTime) {
            try accumulator.advance(by: -1)
        }
        #expect(throws: MatterError.invalidElapsedTime) {
            try accumulator.advance(by: .infinity)
        }
    }

    @Test("Accumulator emits bounded ticks, interpolation, and dropped time")
    func fixedStepAccumulation() throws {
        var accumulator = try FixedStepAccumulator(
            fixedTimeStep: 0.1,
            maximumTicksPerAdvance: 2
        )
        var advance = try accumulator.advance(by: 0.025)
        #expect(advance.tickCount == 0)
        #expect(abs(advance.interpolationAlpha - 0.25) < 0.000_01)
        #expect(advance.droppedTime == 0)

        advance = try accumulator.advance(by: 0.075)
        #expect(advance.tickCount == 1)
        #expect(abs(advance.interpolationAlpha) < 0.000_01)

        advance = try accumulator.advance(by: 0.35)
        #expect(advance.tickCount == 2)
        #expect(abs(advance.droppedTime - 0.15) < 0.000_01)
        #expect(abs(accumulator.totalDroppedTime - 0.15) < 0.000_01)
        #expect(abs(accumulator.interpolationAlpha) < 0.000_01)

        let zero = try accumulator.advance(by: 0)
        #expect(zero.tickCount == 0)
        #expect(zero.droppedTime == 0)
    }

    @Test("Pause, resume, and reset preserve only requested timing state")
    func accumulatorLifecycle() throws {
        var accumulator = try FixedStepAccumulator(fixedTimeStep: 0.1)
        _ = try accumulator.advance(by: 0.05)
        accumulator.pause()
        let paused = try accumulator.advance(by: 10)
        #expect(accumulator.isPaused)
        #expect(paused.tickCount == 0)
        #expect(paused.interpolationAlpha == 0.5)
        #expect(paused.droppedTime == 0)

        accumulator.reset(keepingPauseState: true)
        #expect(accumulator.isPaused)
        #expect(accumulator.interpolationAlpha == 0)
        #expect(accumulator.totalDroppedTime == 0)
        accumulator.resume()
        #expect(!accumulator.isPaused)

        accumulator.pause()
        accumulator.reset()
        #expect(!accumulator.isPaused)
    }

    #if canImport(Metal)
        @Test("Runner schedules ticks and exposes interpolation snapshots")
        func runnerAdvancesAndPauses() async throws {
            guard MetalBackend.isAvailable else { return }
            let engine = try Engine(gravity: .zero, fixedTimeStep: 0.1)
            let runner = try Runner(engine: engine, maximumTicksPerAdvance: 2)

            var update = try await runner.advance(by: 0.05)
            #expect(update.tickCount == 0)
            #expect(update.world.bodyCount == 0)
            #expect(update.collisions.isEmpty)
            #expect(update.collisionEvents.isEmpty)
            #expect(update.sleepingEvents.isEmpty)
            #expect(abs(update.interpolationAlpha - 0.5) < 0.000_01)

            await runner.pause()
            update = try await runner.advance(by: 1)
            #expect(update.tickCount == 0)
            #expect(await runner.timingSnapshot().isPaused)

            await runner.resume()
            update = try await runner.advance(by: 0.05)
            #expect(update.tickCount == 1)
            #expect(abs(update.interpolationAlpha) < 0.000_01)

            update = try await runner.advance(by: 0.5)
            #expect(update.tickCount == 2)
            #expect(abs(update.droppedTime - 0.3) < 0.000_01)
            await runner.resetTiming()
            #expect(await runner.timingSnapshot().interpolationAlpha == 0)
            #expect(await runner.timingSnapshot().totalDroppedTime == 0)
        }

        @Test("Runner reset clears engine collision lifecycle and timing")
        func runnerReset() async throws {
            guard MetalBackend.isAvailable else { return }
            var initialWorld = World()
            _ = try initialWorld.add(
                BodyDefinition(
                    shape: .circle(radius: 2),
                    position: .zero,
                    isStatic: true,
                    isSensor: true
                )
            )
            _ = try initialWorld.add(
                Bodies.circle(at: Vector(x: 1, y: 0), radius: 2, isStatic: true)
            )
            let engine = try Engine(world: initialWorld, gravity: .zero, fixedTimeStep: 0.1)
            let runner = try Runner(engine: engine)

            var update = try await runner.advance(by: 0.1)
            #expect(update.collisionEvents.map(\.phase) == [.started])
            update = try await runner.advance(by: 0.1)
            #expect(update.collisionEvents.map(\.phase) == [.active])

            await runner.reset(to: initialWorld)
            update = try await runner.advance(by: 0.1)
            #expect(update.collisionEvents.map(\.phase) == [.started])
            #expect(await runner.timingSnapshot().totalDroppedTime == 0)
        }

        @Test("Runner checks cancellation before consuming elapsed time")
        func runnerCancellation() async throws {
            guard MetalBackend.isAvailable else { return }
            let runner = try Runner(engine: Engine(gravity: .zero))
            let task = Task {
                try await runner.advance(by: 1)
            }
            task.cancel()
            await #expect(throws: CancellationError.self) {
                try await task.value
            }
            #expect(await runner.timingSnapshot().interpolationAlpha == 0)
        }
    #endif
}
