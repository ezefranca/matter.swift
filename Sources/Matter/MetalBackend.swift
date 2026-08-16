#if canImport(Metal)
    import Foundation
    import Metal

    /// Typed failures from initialization and execution of the Metal backend.
    @frozen
    public enum MetalBackendError: Error, Sendable, Equatable {
        /// No default Metal device is available to this process.
        case unavailable
        /// The bundled integration shader could not be read.
        case kernelSourceUnavailable
        /// Metal rejected the integration shader source.
        case kernelCompilationFailed(message: String)
        /// The compiled library does not contain the expected integration function.
        case kernelFunctionUnavailable(name: String)
        /// Metal could not create a compute pipeline for the integration function.
        case pipelineCreationFailed(message: String)
        /// The device could not create a command queue.
        case commandQueueCreationFailed
        /// The device could not allocate shared body-state storage.
        case bodyBufferCreationFailed
        /// The command queue could not create a command buffer.
        case commandBufferCreationFailed
        /// The command buffer could not create a compute encoder.
        case commandEncoderCreationFailed
        /// Swift's body-state stride no longer matches the Metal shader structure.
        case incompatibleBodyLayout(expected: Int, actual: Int)
        /// A committed command buffer finished without reaching the completed state.
        case commandExecutionFailed(status: Int, message: String)
    }

    private struct GPUBodyState {
        var positionX: Float
        var positionY: Float
        var velocityX: Float
        var velocityY: Float
        var forceX: Float
        var forceY: Float
        var inverseMass: Float
        var angle: Float
        var angularVelocity: Float
        var torque: Float
        var inverseInertia: Float
        var airFriction: Float
        var isStatic: UInt32

        init(_ body: Body) {
            positionX = body.position.x
            positionY = body.position.y
            velocityX = body.velocity.x
            velocityY = body.velocity.y
            forceX = body.force.x
            forceY = body.force.y
            inverseMass = body.inverseMass
            angle = body.angle
            angularVelocity = body.angularVelocity
            torque = body.torque
            inverseInertia = body.inverseInertia
            airFriction = body.material.airFriction
            isStatic = body.isStatic || body.isSleeping ? 1 : 0
        }

        func applied(to body: Body) -> Body {
            var result = body
            result.replaceKinematics(
                position: Vector(x: positionX, y: positionY),
                angle: angle,
                velocity: Vector(x: velocityX, y: velocityY),
                angularVelocity: angularVelocity
            )
            return result
        }
    }

    actor CommandCompletion {
        private enum State {
            case pending([CheckedContinuation<Void, Error>])
            case completed
            case cancelled
        }

        private var state = State.pending([])

        func wait() async throws {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                switch state {
                case let .pending(continuations):
                    state = .pending(continuations + [continuation])
                case .completed:
                    continuation.resume()
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                }
            }
        }

        func complete() {
            guard case let .pending(continuations) = state else {
                return
            }
            state = .completed
            for continuation in continuations {
                continuation.resume()
            }
        }

        func cancel() {
            guard case let .pending(continuations) = state else {
                return
            }
            state = .cancelled
            for continuation in continuations {
                continuation.resume(throwing: CancellationError())
            }
        }

        func waitRespectingTaskCancellation() async throws {
            try await withTaskCancellationHandler(
                operation: {
                    try await wait()
                    try Task.checkCancellation()
                },
                onCancel: {
                    Task {
                        await self.cancel()
                    }
                }
            )
        }
    }

    struct MetalBackendResources {
        let device: any MTLDevice
        let commandQueue: any MTLCommandQueue
        let pipeline: any MTLComputePipelineState
    }

    struct MetalResourceFactory: @unchecked Sendable {
        var makeDevice: () -> (any MTLDevice)?
        var bodyStride: () -> Int
        var loadKernelSource: () -> String?
        var makeDefaultLibrary: (any MTLDevice) -> (any MTLLibrary)?
        var makeLibrary: (any MTLDevice, String) throws -> any MTLLibrary
        var makeFunction: (any MTLLibrary, String) -> (any MTLFunction)?
        var makePipeline: (any MTLDevice, any MTLFunction) throws -> any MTLComputePipelineState
        var makeCommandQueue: (any MTLDevice) -> (any MTLCommandQueue)?

        static let system = Self(
            makeDevice: { MTLCreateSystemDefaultDevice() },
            bodyStride: { MemoryLayout<GPUBodyState>.stride },
            loadKernelSource: {
                loadKernelSource(
                    from: Bundle.module.url(
                        forResource: "Integration",
                        withExtension: "metal"
                    )
                )
            },
            makeDefaultLibrary: { device in
                try? device.makeDefaultLibrary(bundle: Bundle.module)
            },
            makeLibrary: { device, source in
                try device.makeLibrary(source: source, options: nil)
            },
            makeFunction: { library, name in
                library.makeFunction(name: name)
            },
            makePipeline: { device, function in
                try device.makeComputePipelineState(function: function)
            },
            makeCommandQueue: { device in
                device.makeCommandQueue()
            }
        )

        static func loadKernelSource(from sourceURL: URL?) -> String? {
            guard let sourceURL else { return nil }
            return try? String(contentsOf: sourceURL, encoding: .utf8)
        }
    }

    struct MetalExecutionHooks: @unchecked Sendable {
        var makeBodyBuffer: @Sendable (any MTLDevice, Int) -> (any MTLBuffer)?
        var makeCommandBuffer: @Sendable (any MTLCommandQueue) -> (any MTLCommandBuffer)?
        var makeCommandEncoder: @Sendable (any MTLCommandBuffer) -> (any MTLComputeCommandEncoder)?
        var validateCompletion: @Sendable (any MTLCommandBuffer) throws -> Void

        static let system = Self(
            makeBodyBuffer: { device, byteCount in
                device.makeBuffer(length: byteCount, options: .storageModeShared)
            },
            makeCommandBuffer: { commandQueue in
                commandQueue.makeCommandBuffer()
            },
            makeCommandEncoder: { commandBuffer in
                commandBuffer.makeComputeCommandEncoder()
            },
            validateCompletion: { commandBuffer in
                guard commandBuffer.status == .completed else {
                    throw MetalBackendError.commandExecutionFailed(
                        status: Int(commandBuffer.status.rawValue),
                        message: commandBuffer.error?.localizedDescription
                            ?? "The command buffer did not complete."
                    )
                }
            }
        )
    }

    /// The actor-isolated implementation responsible for one Metal integration pass.
    public actor MetalBackend {
        private let device: any MTLDevice
        private let commandQueue: any MTLCommandQueue
        private let pipeline: any MTLComputePipelineState
        private let executionHooks: MetalExecutionHooks
        private var reusableBodyBuffer: (any MTLBuffer)?
        private var statisticsValue: MetalBackendStatistics

        /// Whether this process can create a default Metal device.
        public static var isAvailable: Bool {
            MTLCreateSystemDefaultDevice() != nil
        }

        /// Creates the Metal device and compiles the bundled integration kernel.
        public init() throws {
            let resources = try Self.makeResources(using: .system)
            self.device = resources.device
            self.pipeline = resources.pipeline
            self.commandQueue = resources.commandQueue
            self.executionHooks = .system
            self.reusableBodyBuffer = nil
            self.statisticsValue = MetalBackendStatistics()
        }

        init(
            resourceFactory: MetalResourceFactory = .system,
            executionHooks: MetalExecutionHooks = .system
        ) throws {
            let resources = try Self.makeResources(using: resourceFactory)
            self.device = resources.device
            self.pipeline = resources.pipeline
            self.commandQueue = resources.commandQueue
            self.executionHooks = executionHooks
            self.reusableBodyBuffer = nil
            self.statisticsValue = MetalBackendStatistics()
        }

        private static func makeResources(
            using factory: MetalResourceFactory
        ) throws -> MetalBackendResources {
            guard let device = factory.makeDevice() else {
                throw MetalBackendError.unavailable
            }
            let actualBodyStride = factory.bodyStride()
            guard actualBodyStride == 52 else {
                throw MetalBackendError.incompatibleBodyLayout(
                    expected: 52,
                    actual: actualBodyStride
                )
            }
            let library: any MTLLibrary
            if let source = factory.loadKernelSource() {
                do {
                    library = try factory.makeLibrary(device, source)
                } catch {
                    throw MetalBackendError.kernelCompilationFailed(
                        message: error.localizedDescription
                    )
                }
            } else if let compiledLibrary = factory.makeDefaultLibrary(device) {
                library = compiledLibrary
            } else {
                throw MetalBackendError.kernelSourceUnavailable
            }
            guard let function = factory.makeFunction(library, "integrateBodies") else {
                throw MetalBackendError.kernelFunctionUnavailable(name: "integrateBodies")
            }

            let createdPipeline: any MTLComputePipelineState
            do {
                createdPipeline = try factory.makePipeline(device, function)
            } catch {
                throw MetalBackendError.pipelineCreationFailed(message: error.localizedDescription)
            }
            guard let commandQueue = factory.makeCommandQueue(device) else {
                throw MetalBackendError.commandQueueCreationFailed
            }

            return MetalBackendResources(
                device: device,
                commandQueue: commandQueue,
                pipeline: createdPipeline
            )
        }

        /// Integrates a body snapshot on the GPU without changing the input values.
        public func integrate(
            bodies: [Body],
            gravity: Vector,
            timeStep: Float
        ) async throws -> [Body] {
            guard timeStep.isFinite, timeStep > 0 else {
                throw MatterError.invalidTimeStep
            }
            guard gravity.isFinite else { throw MatterError.invalidVector }
            try Task.checkCancellation()
            guard !bodies.isEmpty else { return [] }

            var states = bodies.map(GPUBodyState.init)
            let byteCount = states.count * MemoryLayout<GPUBodyState>.stride
            let bodyBuffer = try reusableBuffer(byteCount: byteCount)
            states.withUnsafeBytes { source in
                _ = source.copyBytes(
                    to: UnsafeMutableRawBufferPointer(
                        start: bodyBuffer.contents(),
                        count: byteCount
                    )
                )
            }

            guard let commandBuffer = executionHooks.makeCommandBuffer(commandQueue) else {
                throw MetalBackendError.commandBufferCreationFailed
            }
            guard let encoder = executionHooks.makeCommandEncoder(commandBuffer) else {
                throw MetalBackendError.commandEncoderCreationFailed
            }

            var gravity = SIMD2<Float>(gravity.x, gravity.y)
            var bodyCount = UInt32(states.count)
            var timeStep = timeStep
            encoder.setComputePipelineState(pipeline)
            encoder.setBuffer(bodyBuffer, offset: 0, index: 0)
            encoder.setBytes(&gravity, length: MemoryLayout.size(ofValue: gravity), index: 1)
            encoder.setBytes(&bodyCount, length: MemoryLayout.size(ofValue: bodyCount), index: 2)
            encoder.setBytes(&timeStep, length: MemoryLayout.size(ofValue: timeStep), index: 3)

            let threadWidth = min(pipeline.threadExecutionWidth, states.count)
            encoder.dispatchThreads(
                MTLSize(width: states.count, height: 1, depth: 1),
                threadsPerThreadgroup: MTLSize(width: threadWidth, height: 1, depth: 1)
            )
            encoder.endEncoding()

            try await commitAndWait(commandBuffer)
            try executionHooks.validateCompletion(commandBuffer)

            let output = bodyBuffer.contents().bindMemory(
                to: GPUBodyState.self,
                capacity: states.count
            )
            states = Array(UnsafeBufferPointer(start: output, count: states.count))
            statisticsValue.completedPassCount += 1
            statisticsValue.integratedBodyCount += states.count
            return zip(bodies, states).map { $1.applied(to: $0) }
        }

        /// Returns current integration and reusable-resource statistics.
        public func statistics() -> MetalBackendStatistics {
            statisticsValue
        }

        /// Releases retained shared body storage without resetting lifetime counters.
        ///
        /// Call this between simulation ticks when reclaiming memory is more important
        /// than avoiding an allocation on the next nonempty integration pass.
        public func purgeReusableResources() {
            reusableBodyBuffer = nil
            statisticsValue.retainedBodyCapacity = 0
        }

        private func reusableBuffer(byteCount: Int) throws -> any MTLBuffer {
            if let reusableBodyBuffer, reusableBodyBuffer.length >= byteCount {
                statisticsValue.bufferReuseCount += 1
                return reusableBodyBuffer
            }
            guard let bodyBuffer = executionHooks.makeBodyBuffer(device, byteCount) else {
                throw MetalBackendError.bodyBufferCreationFailed
            }
            reusableBodyBuffer = bodyBuffer
            let capacity = bodyBuffer.length / MemoryLayout<GPUBodyState>.stride
            statisticsValue.bufferAllocationCount += 1
            statisticsValue.retainedBodyCapacity = capacity
            statisticsValue.peakBodyCapacity = max(
                statisticsValue.peakBodyCapacity,
                capacity
            )
            return bodyBuffer
        }

        /// Metal cannot cancel an already committed command buffer.
        ///
        /// The completion actor resumes a checked continuation for either Metal
        /// completion or task cancellation, so a cancelled caller is not forced to
        /// await GPU completion.
        private func commitAndWait(_ commandBuffer: any MTLCommandBuffer) async throws {
            try Task.checkCancellation()
            let completion = CommandCompletion()
            commandBuffer.addCompletedHandler { _ in
                Task {
                    await completion.complete()
                }
            }
            commandBuffer.commit()

            try await completion.waitRespectingTaskCancellation()
        }
    }
#else
    /// Typed failures from initialization and execution of the Metal backend.
    @frozen
    public enum MetalBackendError: Error, Sendable, Equatable {
        /// Metal is unavailable on the current platform.
        case unavailable
    }

    /// A platform stub that always reports Metal's absence rather than falling back.
    public actor MetalBackend {
        /// Always `false` on platforms without the Metal framework.
        public static let isAvailable = false

        /// Reports that the platform cannot construct a Metal backend.
        public init() throws {
            throw MetalBackendError.unavailable
        }

        /// Reports that the platform cannot integrate bodies with Metal.
        public func integrate(
            bodies: [Body],
            gravity: Vector,
            timeStep: Float
        ) async throws -> [Body] {
            throw MetalBackendError.unavailable
        }

        /// Reports zero work because this platform cannot construct a backend.
        public func statistics() -> MetalBackendStatistics {
            MetalBackendStatistics()
        }

        /// Has no retained resources on platforms without Metal.
        public func purgeReusableResources() {}
    }
#endif

/// An immutable snapshot of Metal integration work and reusable-buffer usage.
@frozen
public struct MetalBackendStatistics: Sendable, Hashable, Codable {
    /// Integration passes that completed successfully.
    public internal(set) var completedPassCount: Int
    /// Body records processed by completed integration passes.
    public internal(set) var integratedBodyCount: Int
    /// Shared body-buffer allocations made during the backend lifetime.
    public internal(set) var bufferAllocationCount: Int
    /// Passes that reused an existing shared body buffer.
    public internal(set) var bufferReuseCount: Int
    /// Body records that fit in the currently retained shared buffer.
    public internal(set) var retainedBodyCapacity: Int
    /// Largest retained body capacity observed during the backend lifetime.
    public internal(set) var peakBodyCapacity: Int

    init(
        completedPassCount: Int = 0,
        integratedBodyCount: Int = 0,
        bufferAllocationCount: Int = 0,
        bufferReuseCount: Int = 0,
        retainedBodyCapacity: Int = 0,
        peakBodyCapacity: Int = 0
    ) {
        self.completedPassCount = completedPassCount
        self.integratedBodyCount = integratedBodyCount
        self.bufferAllocationCount = bufferAllocationCount
        self.bufferReuseCount = bufferReuseCount
        self.retainedBodyCapacity = retainedBodyCapacity
        self.peakBodyCapacity = peakBodyCapacity
    }
}

/// A stable simulation stage whose execution ownership affects performance.
@frozen
public enum MatterExecutionStage: String, CaseIterable, Sendable, Hashable, Codable {
    /// Semi-implicit linear and angular body integration.
    case integration
    /// Candidate-pair generation from cached world-space bounds.
    case broadPhase
    /// Exact manifold and contact generation for candidate pairs.
    case narrowPhase
    /// Iterative distance, angular, and pointer-constraint solving.
    case constraintSolving
    /// Warm-started contact impulses and positional correction.
    case collisionResponse
}

/// The processor that owns a stage in Matter's production execution plan.
@frozen
public enum MatterExecutionBackend: String, Sendable, Hashable, Codable {
    /// A Metal compute kernel and shared Metal resources.
    case metal
    /// Deterministic actor-isolated native Swift code on the CPU.
    case cpu
}

/// Matter's explicit, non-fallback production execution policy.
///
/// Integration is regular per-body data-parallel work and runs on Metal. The
/// adaptive broad phase, exact narrow phase, constraints, and collision response
/// remain CPU-owned because they are branch-heavy, topology-dependent stages with
/// deterministic value-semantic implementations and benchmarked scaling.
@frozen
public struct MatterExecutionPolicy: Sendable, Hashable, Codable {
    /// The production policy used by ``Engine``.
    public static let native = Self()

    private init() {}

    /// Returns the processor that always owns `stage` in the production engine.
    public func backend(for stage: MatterExecutionStage) -> MatterExecutionBackend {
        switch stage {
        case .integration:
            .metal
        case .broadPhase, .narrowPhase, .constraintSolving, .collisionResponse:
            .cpu
        }
    }
}
