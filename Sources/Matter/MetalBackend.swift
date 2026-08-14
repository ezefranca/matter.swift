#if canImport(Metal)
import Foundation
import Metal

/// Typed failures from initialization and execution of the Metal backend.
@frozen
public enum MetalBackendError: Error, Sendable, Equatable {
    case unavailable
    case kernelSourceUnavailable
    case kernelCompilationFailed(message: String)
    case kernelFunctionUnavailable(name: String)
    case pipelineCreationFailed(message: String)
    case commandQueueCreationFailed
    case bodyBufferCreationFailed
    case commandBufferCreationFailed
    case commandEncoderCreationFailed
    case incompatibleBodyLayout(expected: Int, actual: Int)
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
    var isStatic: UInt32

    init(_ body: Body) {
        positionX = body.position.x
        positionY = body.position.y
        velocityX = body.velocity.x
        velocityY = body.velocity.y
        forceX = body.force.x
        forceY = body.force.y
        inverseMass = body.inverseMass
        isStatic = body.isStatic ? 1 : 0
    }

    func applied(to body: Body) -> Body {
        var result = body
        result.position = Vector(x: positionX, y: positionY)
        result.velocity = Vector(x: velocityX, y: velocityY)
        result.clearForce()
        return result
    }
}

private actor CommandCompletion {
    private enum State {
        case pending
        case waiting(CheckedContinuation<Void, Error>)
        case completed
        case cancelled
    }

    private var state = State.pending

    func wait() async throws {
        try Task.checkCancellation()
        try await withCheckedThrowingContinuation { continuation in
            switch state {
            case .pending:
                state = .waiting(continuation)
            case .waiting:
                preconditionFailure("A command completion can only be awaited once.")
            case .completed:
                continuation.resume()
            case .cancelled:
                continuation.resume(throwing: CancellationError())
            }
        }
    }

    func complete() {
        guard case let .waiting(continuation) = state else {
            if case .pending = state {
                state = .completed
            }
            return
        }
        state = .completed
        continuation.resume()
    }

    func cancel() {
        guard case let .waiting(continuation) = state else {
            if case .pending = state {
                state = .cancelled
            }
            return
        }
        state = .cancelled
        continuation.resume(throwing: CancellationError())
    }
}

/// The actor-isolated implementation responsible for one Metal integration pass.
public actor MetalBackend {
    private let device: any MTLDevice
    private let commandQueue: any MTLCommandQueue
    private let pipeline: any MTLComputePipelineState

    /// Whether this process can create a default Metal device.
    public static var isAvailable: Bool {
        MTLCreateSystemDefaultDevice() != nil
    }

    /// Creates the Metal device and compiles the bundled integration kernel.
    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalBackendError.unavailable
        }
        guard MemoryLayout<GPUBodyState>.stride == 32 else {
            throw MetalBackendError.incompatibleBodyLayout(
                expected: 32,
                actual: MemoryLayout<GPUBodyState>.stride
            )
        }
        guard let sourceURL = Bundle.module.url(
            forResource: "Integration",
            withExtension: "metal"
        ), let source = try? String(contentsOf: sourceURL, encoding: .utf8) else {
            throw MetalBackendError.kernelSourceUnavailable
        }

        let library: any MTLLibrary
        do {
            library = try device.makeLibrary(source: source, options: nil)
        } catch {
            throw MetalBackendError.kernelCompilationFailed(message: error.localizedDescription)
        }
        guard let function = library.makeFunction(name: "integrateBodies") else {
            throw MetalBackendError.kernelFunctionUnavailable(name: "integrateBodies")
        }

        let createdPipeline: any MTLComputePipelineState
        do {
            createdPipeline = try device.makeComputePipelineState(function: function)
        } catch {
            throw MetalBackendError.pipelineCreationFailed(message: error.localizedDescription)
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalBackendError.commandQueueCreationFailed
        }

        self.device = device
        self.pipeline = createdPipeline
        self.commandQueue = commandQueue
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
        try Task.checkCancellation()
        guard !bodies.isEmpty else { return [] }

        var states = bodies.map(GPUBodyState.init)
        let byteCount = states.count * MemoryLayout<GPUBodyState>.stride
        guard let bodyBuffer = device.makeBuffer(
            length: byteCount,
            options: .storageModeShared
        ) else {
            throw MetalBackendError.bodyBufferCreationFailed
        }
        states.withUnsafeBytes { source in
            bodyBuffer.contents().copyMemory(
                from: source.baseAddress!,
                byteCount: byteCount
            )
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalBackendError.commandBufferCreationFailed
        }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
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
        guard commandBuffer.status == .completed else {
            throw MetalBackendError.commandExecutionFailed(
                status: Int(commandBuffer.status.rawValue),
                message: commandBuffer.error?.localizedDescription ?? "The command buffer did not complete."
            )
        }

        let output = bodyBuffer.contents().bindMemory(
            to: GPUBodyState.self,
            capacity: states.count
        )
        states = Array(UnsafeBufferPointer(start: output, count: states.count))
        return zip(bodies, states).map { $1.applied(to: $0) }
    }

    /// Metal cannot cancel an already committed command buffer. The completion
    /// actor resumes a checked continuation for either Metal completion or task
    /// cancellation, so a cancelled caller is not forced to await GPU completion.
    private func commitAndWait(_ commandBuffer: any MTLCommandBuffer) async throws {
        try Task.checkCancellation()
        let completion = CommandCompletion()
        commandBuffer.addCompletedHandler { _ in
            Task {
                await completion.complete()
            }
        }
        commandBuffer.commit()

        try await withTaskCancellationHandler(
            operation: {
                try await completion.wait()
                try Task.checkCancellation()
            },
            onCancel: {
                Task {
                    await completion.cancel()
                }
            }
        )
    }
}
#else
/// Typed failures from initialization and execution of the Metal backend.
@frozen
public enum MetalBackendError: Error, Sendable, Equatable {
    case unavailable
}

/// A platform stub that always reports Metal's absence rather than falling back.
public actor MetalBackend {
    /// Always `false` on platforms without the Metal framework.
    public static let isAvailable = false

    public init() throws {
        throw MetalBackendError.unavailable
    }

    public func integrate(
        bodies: [Body],
        gravity: Vector,
        timeStep: Float
    ) async throws -> [Body] {
        throw MetalBackendError.unavailable
    }
}
#endif
