/// The lifecycle phase of a stable collision pair.
@frozen
public enum CollisionPhase: String, Sendable, Hashable, Codable, CaseIterable {
    /// The pair was absent from the preceding tick and is now colliding.
    case started

    /// The pair was colliding in both the preceding and current ticks.
    case active

    /// The pair was colliding in the preceding tick and is now absent.
    case ended
}

/// One deterministic collision lifecycle event.
@frozen
public struct CollisionEvent: Sendable, Hashable, Codable {
    /// Whether the collision started, remained active, or ended.
    public let phase: CollisionPhase

    /// The current collision, or the last known manifold for an ended pair.
    public let collision: Collision

    /// The canonical body identities for this event.
    public var pair: BodyPair {
        collision.pair
    }

    init(phase: CollisionPhase, collision: Collision) {
        self.phase = phase
        self.collision = collision
    }
}

/// Value-semantic state that converts collision snapshots into lifecycle events.
@frozen
public struct CollisionTracker: Sendable, Hashable, Codable {
    private var previousCollisions: [BodyPair: Collision]

    /// Creates a tracker with no active pairs.
    public init() {
        previousCollisions = [:]
    }

    /// Canonical pairs active in the most recently tracked snapshot.
    public var activePairs: [BodyPair] {
        previousCollisions.keys.sorted()
    }

    /// Replaces tracked collision state and returns ordered lifecycle events.
    ///
    /// When input repeats a pair, its last collision value is retained.
    public mutating func update(with collisions: [Collision]) -> [CollisionEvent] {
        var current: [BodyPair: Collision] = [:]
        for collision in collisions {
            current[collision.pair] = collision
        }
        var events = current.values.sorted { $0.pair < $1.pair }.map { collision in
            CollisionEvent(
                phase: previousCollisions[collision.pair] == nil ? .started : .active,
                collision: collision
            )
        }

        let endedCollisions = previousCollisions.values
            .filter { current[$0.pair] == nil }
            .sorted { $0.pair < $1.pair }
        events.append(
            contentsOf: endedCollisions.map { collision in
                CollisionEvent(phase: .ended, collision: collision)
            }
        )
        previousCollisions = current
        return events
    }

    /// Clears active state so the next collision snapshot emits start events.
    public mutating func reset() {
        previousCollisions.removeAll(keepingCapacity: true)
    }
}

/// The immutable outcome of one or more fixed engine ticks.
@frozen
public struct SimulationResult: Sendable, Hashable, Codable {
    /// The world after integration and collision response.
    public let world: World

    /// The number of fixed ticks represented by this result.
    public let tickCount: Int

    /// Collisions detected during the final tick before positional correction.
    public let collisions: [Collision]

    /// Ordered lifecycle events accumulated across every requested tick.
    public let collisionEvents: [CollisionEvent]

    init(
        world: World,
        tickCount: Int,
        collisions: [Collision],
        collisionEvents: [CollisionEvent]
    ) {
        self.world = world
        self.tickCount = tickCount
        self.collisions = collisions
        self.collisionEvents = collisionEvents
    }
}
