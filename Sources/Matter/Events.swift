import Foundation

/// Backpressure behavior for a simulation-event subscription.
@frozen
public enum MatterEventBufferingPolicy: Sendable, Hashable, Codable {
    /// Retains every undelivered simulation result.
    case unbounded
    /// Retains only the newest `limit` undelivered results.
    case bufferingNewest(Int)
    /// Retains only the oldest `limit` undelivered results.
    case bufferingOldest(Int)

    func asyncStreamPolicy() throws
        -> AsyncStream<SimulationResult>.Continuation.BufferingPolicy
    {
        switch self {
        case .unbounded:
            return .unbounded
        case let .bufferingNewest(limit):
            guard limit > 0 else { throw MatterError.invalidEventBufferCapacity }
            return .bufferingNewest(limit)
        case let .bufferingOldest(limit):
            guard limit > 0 else { throw MatterError.invalidEventBufferCapacity }
            return .bufferingOldest(limit)
        }
    }
}

/// One independently cancellable stream of successful engine results.
public struct MatterEventSubscription: Sendable {
    let identifier: UUID
    let engine: Engine

    /// Results published after successful ``Engine/stepWithEvents(ticks:)`` calls.
    public let stream: AsyncStream<SimulationResult>

    init(identifier: UUID, engine: Engine, stream: AsyncStream<SimulationResult>) {
        self.identifier = identifier
        self.engine = engine
        self.stream = stream
    }

    /// Finishes this stream and releases its slot in the engine.
    ///
    /// Cancellation is idempotent and does not stop or mutate simulation work.
    public func cancel() async {
        await engine.cancelEventSubscription(identifier)
    }
}

/// Typed subscription management for ``Engine`` and ``Runner`` simulation events.
@frozen
public enum Events {
    /// Subscribes to immutable results from future successful engine steps.
    ///
    /// A runner publishes through the same stream because it delegates fixed work
    /// to its engine. The subscription does not replay results produced before
    /// this call.
    ///
    /// - Parameters:
    ///   - engine: The actor that owns and publishes simulation results.
    ///   - bufferingPolicy: How undelivered results should be retained.
    /// - Returns: A subscription whose stream is safe to consume from any actor.
    /// - Throws: ``MatterError/invalidEventBufferCapacity`` for a bounded policy
    ///   whose limit is not positive.
    public static func subscribe(
        to engine: Engine,
        bufferingPolicy: MatterEventBufferingPolicy = .bufferingNewest(1)
    ) async throws -> MatterEventSubscription {
        try await engine.makeEventSubscription(bufferingPolicy: bufferingPolicy)
    }

    /// Finishes and removes every active subscription from an engine.
    ///
    /// Existing simulation work and future subscriptions are unaffected.
    public static func removeAll(from engine: Engine) async {
        await engine.cancelAllEventSubscriptions()
    }
}
