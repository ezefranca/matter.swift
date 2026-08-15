import Foundation
import Testing

@testable import Matter

#if canImport(Metal)
    import Metal

    private enum SyntheticMetalFailure: LocalizedError {
        case expected

        var errorDescription: String? {
            "Synthetic Metal failure."
        }
    }
#endif

@Suite("Matter validation and state")
struct MatterValidationTests {
    @Test("Body identifiers are raw-representable and ordered")
    func bodyIdentifiers() {
        let lower = BodyID(rawValue: 1)
        let upper = BodyID(rawValue: 2)

        #expect(lower.rawValue == 1)
        #expect(lower < upper)
        #expect([upper, lower].sorted() == [lower, upper])
    }

    @Test(
        "Shapes reject nonpositive and nonfinite dimensions",
        arguments: [
            BodyShape.circle(radius: 0),
            BodyShape.circle(radius: -.infinity),
            BodyShape.rectangle(width: 0, height: 1),
            BodyShape.rectangle(width: 1, height: .infinity),
        ]
    )
    func invalidShapes(_ shape: BodyShape) {
        #expect(throws: MatterError.invalidShapeDimension) {
            try BodyDefinition(shape: shape, position: .zero)
        }
    }

    @Test(
        "Definitions reject nonpositive and nonfinite masses",
        arguments: [Float(0), Float(-1), Float.infinity]
    )
    func invalidMasses(_ mass: Float) {
        #expect(throws: MatterError.invalidMass) {
            try Bodies.circle(at: .zero, radius: 1, mass: mass)
        }
    }

    @Test("Matter vectors support the complete operator surface")
    func vectorOperators() {
        let first = Vector(x: 4, y: 6)
        let second = Vector(x: 1, y: 2)

        #expect(first.lengthSquared == 52)
        #expect(first - second == Vector(x: 3, y: 4))
        #expect(-second == Vector(x: -1, y: -2))
        #expect(2 * second == Vector(x: 2, y: 4))
        #expect(first / 2 == Vector(x: 2, y: 3))
        #expect(Vector.zero.normalized() == .zero)

        var value = first
        value -= second
        #expect(value == Vector(x: 3, y: 4))
    }

    @Test("World and body state round-trip through Codable")
    func worldCodableRoundTrip() throws {
        var world = World()
        let identifier = try world.add(
            Bodies.rectangle(
                at: Vector(x: 3, y: 4),
                width: 10,
                height: 20,
                velocity: Vector(x: 1, y: 2),
                mass: 5
            )
        )
        try world.applyForce(Vector(x: 7, y: 8), to: identifier)

        let data = try JSONEncoder().encode(world)
        let decoded = try JSONDecoder().decode(World.self, from: data)

        #expect(decoded == world)
        #expect(decoded.body(withID: identifier)?.force == Vector(x: 7, y: 8))
    }

    @Test("A world reports an unknown body instead of dropping force")
    func unknownBody() {
        var world = World()
        let missing = BodyID(rawValue: 42)

        #expect(throws: MatterError.unknownBody(missing)) {
            try world.applyForce(Vector(x: 1, y: 1), to: missing)
        }
        #expect(world.body(withID: missing) == nil)
    }

    @Test("A decoded exhausted identifier sequence cannot wrap")
    func exhaustedBodyIdentifiers() throws {
        let data = Data(
            #"{"bodies":[],"composites":[],"constraints":[],"nextBodyIdentifier":18446744073709551615,"nextCompositeIdentifier":0,"nextConstraintIdentifier":0}"#
                .utf8
        )
        var world = try JSONDecoder().decode(World.self, from: data)
        let definition = try Bodies.circle(at: .zero, radius: 1)

        #expect(throws: MatterError.bodyIdentifierExhausted) {
            try world.add(definition)
        }
    }

    @Test(
        "Reference integration rejects invalid time steps",
        arguments: [Float(0), Float(-1), Float.infinity]
    )
    func invalidReferenceTimeSteps(_ timeStep: Float) {
        var world = World()

        #expect(throws: MatterError.invalidTimeStep) {
            try ReferenceIntegrator.step(
                world: &world,
                gravity: .zero,
                timeStep: timeStep
            )
        }
    }

    @Test(
        "Engine initialization rejects invalid time steps before Metal setup",
        arguments: [Float(0), Float(-1), Float.infinity]
    )
    func invalidEngineTimeSteps(_ timeStep: Float) {
        #expect(throws: MatterError.invalidTimeStep) {
            _ = try Engine(fixedTimeStep: timeStep)
        }
    }

    @Test("Integration entry points reject nonfinite gravity before mutation")
    func invalidGravity() async throws {
        var world = World()
        _ = try world.add(Bodies.circle(at: .zero, radius: 1))
        let original = world
        #expect(throws: MatterError.invalidVector) {
            try ReferenceIntegrator.step(
                world: &world,
                gravity: Vector(x: .infinity, y: 0),
                timeStep: 0.1
            )
        }
        #expect(world == original)
        #expect(throws: MatterError.invalidVector) {
            _ = try Engine(gravity: Vector(x: 0, y: .nan))
        }

        #if canImport(Metal)
            guard MetalBackend.isAvailable else { return }
            let backend = try MetalBackend()
            await #expect(throws: MatterError.invalidVector) {
                try await backend.integrate(
                    bodies: world.bodies,
                    gravity: Vector(x: .nan, y: 0),
                    timeStep: 0.1
                )
            }
        #endif
    }

    #if canImport(Metal)
        @Test("Engine snapshots and tick validation preserve actor-owned state")
        func engineSnapshotsAndTicks() async throws {
            guard MetalBackend.isAvailable else { return }
            let engine = try Engine(gravity: .zero, fixedTimeStep: 0.01)
            let identifier = try await engine.add(
                Bodies.circle(at: Vector(x: 2, y: 3), radius: 1)
            )

            let snapshot = await engine.snapshot()
            #expect(snapshot.body(withID: identifier)?.position == Vector(x: 2, y: 3))
            await #expect(throws: MatterError.invalidTickCount) {
                try await engine.step(ticks: 0)
            }
        }

        @Test("Metal validates time steps and accepts empty batches")
        func metalInputValidation() async throws {
            guard MetalBackend.isAvailable else { return }
            let backend = try MetalBackend()

            await #expect(throws: MatterError.invalidTimeStep) {
                try await backend.integrate(bodies: [], gravity: .zero, timeStep: 0)
            }
            let output = try await backend.integrate(
                bodies: [],
                gravity: .zero,
                timeStep: 1.0 / 60.0
            )
            #expect(output.isEmpty)
        }

        @Test("A cancelled engine step reports cancellation")
        func cancelledEngineStep() async throws {
            guard MetalBackend.isAvailable else { return }
            let engine = try Engine(gravity: .zero, fixedTimeStep: 0.001)
            _ = try await engine.add(Bodies.circle(at: .zero, radius: 1))

            let task = Task {
                try await engine.step(ticks: 10_000)
            }
            task.cancel()

            await #expect(throws: CancellationError.self) {
                try await task.value
            }
        }

        @Test("Command completion records completion before a waiter arrives")
        func commandCompletesBeforeWait() async throws {
            let completion = CommandCompletion()

            await completion.complete()

            try await completion.wait()
        }

        @Test("Command completion records cancellation before a waiter arrives")
        func commandCancelsBeforeWait() async {
            let completion = CommandCompletion()

            await completion.cancel()

            await #expect(throws: CancellationError.self) {
                try await completion.wait()
            }
        }

        @Test("Command completion can cancel an active waiter")
        func commandCancelsActiveWaiter() async {
            let completion = CommandCompletion()
            let waiter = Task {
                try await completion.wait()
            }
            await Task.yield()

            await completion.cancel()

            await #expect(throws: CancellationError.self) {
                try await waiter.value
            }
        }

        @Test("Command completion supports multiple waiters and idempotent signals")
        func commandCompletionSupportsMultipleWaiters() async throws {
            let completion = CommandCompletion()
            let first = Task { try await completion.wait() }
            let second = Task { try await completion.wait() }
            await Task.yield()

            await completion.complete()
            await completion.complete()
            await completion.cancel()

            try await first.value
            try await second.value
        }

        @Test("Task cancellation cancels a command completion wait")
        func commandCompletionRespectsTaskCancellation() async {
            let completion = CommandCompletion()
            let waiter = Task {
                try await completion.waitRespectingTaskCancellation()
            }
            await Task.yield()

            waiter.cancel()

            await #expect(throws: CancellationError.self) {
                try await waiter.value
            }
        }

        @Test("Metal initialization maps every resource creation failure")
        func metalResourceFailures() throws {
            #expect(MetalResourceFactory.loadKernelSource(from: nil) == nil)

            var factory = MetalResourceFactory.system
            factory.makeDevice = { nil }
            #expect(throws: MetalBackendError.unavailable) {
                _ = try MetalBackend(resourceFactory: factory)
            }

            guard MTLCreateSystemDefaultDevice() != nil else { return }

            factory = .system
            factory.bodyStride = { 64 }
            #expect(
                throws: MetalBackendError.incompatibleBodyLayout(expected: 52, actual: 64)
            ) {
                _ = try MetalBackend(resourceFactory: factory)
            }

            factory = .system
            factory.loadKernelSource = { nil }
            #expect(throws: MetalBackendError.kernelSourceUnavailable) {
                _ = try MetalBackend(resourceFactory: factory)
            }

            factory = .system
            factory.makeLibrary = { _, _ in throw SyntheticMetalFailure.expected }
            #expect(
                throws: MetalBackendError.kernelCompilationFailed(
                    message: "Synthetic Metal failure."
                )
            ) {
                _ = try MetalBackend(resourceFactory: factory)
            }

            factory = .system
            factory.makeFunction = { _, _ in nil }
            #expect(
                throws: MetalBackendError.kernelFunctionUnavailable(name: "integrateBodies")
            ) {
                _ = try MetalBackend(resourceFactory: factory)
            }

            factory = .system
            factory.makePipeline = { _, _ in throw SyntheticMetalFailure.expected }
            #expect(
                throws: MetalBackendError.pipelineCreationFailed(
                    message: "Synthetic Metal failure."
                )
            ) {
                _ = try MetalBackend(resourceFactory: factory)
            }

            factory = .system
            factory.makeCommandQueue = { _ in nil }
            #expect(throws: MetalBackendError.commandQueueCreationFailed) {
                _ = try MetalBackend(resourceFactory: factory)
            }
        }

        @Test("Metal integration maps buffer and command construction failures")
        func metalExecutionFailures() async throws {
            guard MetalBackend.isAvailable else { return }
            var hooks = MetalExecutionHooks.system
            let definition = try Bodies.circle(at: .zero, radius: 1)
            var world = World()
            _ = try world.add(definition)

            hooks.makeBodyBuffer = { _, _ in nil }
            var backend = try MetalBackend(executionHooks: hooks)
            await #expect(throws: MetalBackendError.bodyBufferCreationFailed) {
                try await backend.integrate(
                    bodies: world.bodies,
                    gravity: .zero,
                    timeStep: 1.0 / 60.0
                )
            }

            hooks = .system
            hooks.makeCommandBuffer = { _ in nil }
            backend = try MetalBackend(executionHooks: hooks)
            await #expect(throws: MetalBackendError.commandBufferCreationFailed) {
                try await backend.integrate(
                    bodies: world.bodies,
                    gravity: .zero,
                    timeStep: 1.0 / 60.0
                )
            }

            hooks = .system
            hooks.makeCommandEncoder = { _ in nil }
            backend = try MetalBackend(executionHooks: hooks)
            await #expect(throws: MetalBackendError.commandEncoderCreationFailed) {
                try await backend.integrate(
                    bodies: world.bodies,
                    gravity: .zero,
                    timeStep: 1.0 / 60.0
                )
            }
        }

        @Test("Metal state conversion handles dynamic and static mass branches")
        func metalStaticAndDynamicBodies() async throws {
            guard MetalBackend.isAvailable else { return }
            var world = World()
            _ = try world.add(Bodies.circle(at: .zero, radius: 1, mass: 2))
            _ = try world.add(
                Bodies.rectangle(
                    at: Vector(x: 2, y: 3),
                    width: 4,
                    height: 5,
                    isStatic: true
                )
            )
            #expect(world.bodies[0].inverseMass == 0.5)
            #expect(world.bodies[1].inverseMass == 0)

            let output = try await MetalBackend().integrate(
                bodies: world.bodies,
                gravity: .zero,
                timeStep: 1.0 / 60.0
            )

            #expect(output[0].isStatic == false)
            #expect(output[1].isStatic)
            #expect(output[1].position == Vector(x: 2, y: 3))
        }

        @Test("Metal completion validation reports an unfinished command")
        func metalCommandCompletionFailure() throws {
            guard
                let device = MTLCreateSystemDefaultDevice(),
                let commandQueue = device.makeCommandQueue(),
                let commandBuffer = commandQueue.makeCommandBuffer()
            else {
                return
            }

            #expect(
                throws: MetalBackendError.commandExecutionFailed(
                    status: Int(commandBuffer.status.rawValue),
                    message: "The command buffer did not complete."
                )
            ) {
                try MetalExecutionHooks.system.validateCompletion(commandBuffer)
            }
        }
    #endif
}
