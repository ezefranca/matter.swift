/// Thresholds controlling deterministic body sleeping.
@frozen
public struct SleepingConfiguration: Sendable, Hashable, Codable {
    /// Whether automatic sleeping is active.
    public var enabled: Bool

    /// Maximum linear speed considered quiet, in world units per second.
    public var linearVelocityThreshold: Float

    /// Maximum angular speed considered quiet, in radians per second.
    public var angularVelocityThreshold: Float

    /// Continuous quiet time required before an island sleeps.
    public var minimumQuietTime: Float

    /// Creates sleeping configuration validated when a manager or engine uses it.
    public init(
        enabled: Bool = true,
        linearVelocityThreshold: Float = 0.05,
        angularVelocityThreshold: Float = 0.05,
        minimumQuietTime: Float = 0.5
    ) {
        self.enabled = enabled
        self.linearVelocityThreshold = linearVelocityThreshold
        self.angularVelocityThreshold = angularVelocityThreshold
        self.minimumQuietTime = minimumQuietTime
    }

    /// Stable thresholds suitable for ordinary real-time worlds.
    public static let standard = Self()

    /// A configuration that preserves continuous integration for every body.
    public static let disabled = Self(enabled: false)

    func validate() throws {
        guard
            linearVelocityThreshold.isFinite,
            angularVelocityThreshold.isFinite,
            minimumQuietTime.isFinite,
            linearVelocityThreshold >= 0,
            angularVelocityThreshold >= 0,
            minimumQuietTime > 0
        else {
            throw MatterError.invalidSleepingConfiguration
        }
    }
}

/// A stable connected component of dynamic bodies.
@frozen
public struct SimulationIsland: Sendable, Hashable, Codable, Comparable {
    /// The smallest body identifier in the island.
    public let identifier: BodyID

    /// Dynamic body identifiers in ascending order.
    public let bodyIDs: [BodyID]

    init(bodyIDs: [BodyID]) {
        self.identifier = bodyIDs[0]
        self.bodyIDs = bodyIDs
    }

    /// Orders islands by their smallest body identifier.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.identifier < rhs.identifier
    }
}

/// Builds deterministic simulation islands from contacts and constraints.
@frozen
public enum IslandManager {
    /// Returns dynamic-body islands in stable identifier order.
    ///
    /// When `collisions` is omitted, current world collisions are detected.
    /// Sensors and static bodies do not connect otherwise independent islands.
    public static func islands(
        in world: World,
        collisions: [Collision]? = nil
    ) -> [SimulationIsland] {
        let dynamicIDs = world.bodies.lazy
            .filter { !$0.isStatic }
            .map(\.id)
            .sorted()
        let dynamicSet = Set(dynamicIDs)
        var adjacency: [BodyID: Set<BodyID>] = [:]

        func connect(_ first: BodyID?, _ second: BodyID?) {
            guard
                let first,
                let second,
                first != second,
                dynamicSet.contains(first),
                dynamicSet.contains(second)
            else { return }
            adjacency[first, default: []].insert(second)
            adjacency[second, default: []].insert(first)
        }

        for constraint in world.constraints {
            connect(constraint.first.bodyID, constraint.second.bodyID)
        }
        for collision in collisions ?? CollisionDetector.collisions(in: world)
        where !collision.isSensor {
            connect(collision.pair.first, collision.pair.second)
        }

        var visited: Set<BodyID> = []
        var islands: [SimulationIsland] = []
        for root in dynamicIDs where !visited.contains(root) {
            var pending = [root]
            var bodyIDs: [BodyID] = []
            visited.insert(root)
            while let current = pending.popLast() {
                bodyIDs.append(current)
                for neighbor in adjacency[current, default: []].sorted(by: { $0 < $1 }).reversed()
                where visited.insert(neighbor).inserted {
                    pending.append(neighbor)
                }
            }
            islands.append(SimulationIsland(bodyIDs: bodyIDs.sorted()))
        }
        return islands.sorted()
    }
}

/// Whether an automatic sleeping transition started or ended.
@frozen
public enum SleepingPhase: String, Sendable, Hashable, Codable, CaseIterable {
    /// A quiet dynamic body entered the sleeping state.
    case started

    /// A sleeping dynamic body woke for new work or island activity.
    case ended
}

/// One deterministic body sleeping transition.
@frozen
public struct SleepingEvent: Sendable, Hashable, Codable {
    /// Whether sleeping started or ended.
    public let phase: SleepingPhase

    /// The body whose sleeping state changed.
    public let body: BodyID

    init(phase: SleepingPhase, body: BodyID) {
        self.phase = phase
        self.body = body
    }
}

/// Value-semantic quiet-time state retained across fixed simulation ticks.
@frozen
public struct SleepingState: Sendable, Hashable, Codable {
    private var quietTimes: [BodyID: Float]
    private var previouslySleeping: Set<BodyID>

    /// Creates an empty state with no accumulated quiet time.
    public init() {
        quietTimes = [:]
        previouslySleeping = []
    }

    /// Dynamic bodies currently tracked, in stable identifier order.
    public var trackedBodies: [BodyID] {
        quietTimes.keys.sorted()
    }

    /// Bodies that were sleeping after the most recent completed update.
    public var sleepingBodies: [BodyID] {
        previouslySleeping.sorted()
    }

    /// Returns accumulated quiet time for a tracked body.
    public func quietTime(for body: BodyID) -> Float? {
        quietTimes[body]
    }

    /// Removes every accumulated duration.
    public mutating func reset() {
        quietTimes.removeAll(keepingCapacity: true)
        previouslySleeping.removeAll(keepingCapacity: true)
    }

    mutating func retain(_ identifiers: Set<BodyID>) {
        quietTimes = quietTimes.filter { identifiers.contains($0.key) }
        previouslySleeping.formIntersection(identifiers)
    }

    mutating func resetQuietTimeForWokenBodies(in bodies: [Body]) {
        for body in bodies where previouslySleeping.contains(body.id) && !body.isSleeping {
            quietTimes[body.id] = 0
        }
    }

    mutating func recordSleepingBodies(in bodies: [Body]) {
        previouslySleeping = Set(bodies.lazy.filter(\.isSleeping).map(\.id))
    }

    subscript(body: BodyID) -> Float {
        get { quietTimes[body] ?? 0 }
        set { quietTimes[body] = newValue }
    }
}

/// Coordinates deterministic island-wide sleeping and waking.
@frozen
public enum SleepingManager {
    /// Wakes every sleeping member of an island that also contains an awake body.
    ///
    /// Call this before integration and again after detecting new contacts so
    /// forces, transforms, constraints, and collisions propagate wakefulness.
    @discardableResult
    public static func prepareForStep(
        world: inout World,
        collisions: [Collision]? = nil
    ) -> [SleepingEvent] {
        var bodies = world.bodies
        let indices = Dictionary(uniqueKeysWithValues: bodies.indices.map { (bodies[$0].id, $0) })
        var events: [SleepingEvent] = []
        for island in IslandManager.islands(in: world, collisions: collisions) {
            let islandIndices = island.bodyIDs.compactMap { indices[$0] }
            guard
                islandIndices.contains(where: { bodies[$0].isSleeping }),
                islandIndices.contains(where: { !bodies[$0].isSleeping })
            else { continue }
            for index in islandIndices where bodies[index].isSleeping {
                bodies[index].wake()
                events.append(SleepingEvent(phase: .ended, body: bodies[index].id))
            }
        }
        world.replaceBodies(bodies)
        return events
    }

    /// Updates quiet durations and performs stable island-wide transitions.
    ///
    /// Call after constraint and collision response for a fixed tick. Supplied
    /// collisions should be the contacts resolved during that same tick.
    @discardableResult
    public static func update(
        world: inout World,
        state: inout SleepingState,
        collisions: [Collision]? = nil,
        timeStep: Float,
        configuration: SleepingConfiguration = .standard
    ) throws -> [SleepingEvent] {
        guard timeStep.isFinite, timeStep > 0 else { throw MatterError.invalidTimeStep }
        try configuration.validate()

        let dynamicIDs = Set(world.bodies.lazy.filter { !$0.isStatic }.map(\.id))
        state.retain(dynamicIDs)
        var bodies = world.bodies
        if !configuration.enabled {
            let events = bodies.indices.compactMap { index -> SleepingEvent? in
                guard bodies[index].isSleeping else { return nil }
                bodies[index].wake()
                return SleepingEvent(phase: .ended, body: bodies[index].id)
            }
            state.reset()
            world.replaceBodies(bodies)
            return events
        }

        var events = prepareForStep(world: &world, collisions: collisions)
        bodies = world.bodies
        state.resetQuietTimeForWokenBodies(in: bodies)
        let indices = Dictionary(uniqueKeysWithValues: bodies.indices.map { (bodies[$0].id, $0) })
        for island in IslandManager.islands(in: world, collisions: collisions) {
            let islandIndices = island.bodyIDs.compactMap { indices[$0] }
            let isQuiet = islandIndices.allSatisfy { index in
                let body = bodies[index]
                return body.velocity.lengthSquared
                    <= configuration.linearVelocityThreshold
                    * configuration.linearVelocityThreshold
                    && abs(body.angularVelocity) <= configuration.angularVelocityThreshold
                    && body.force == .zero
                    && body.torque == 0
            }
            guard isQuiet else {
                for index in islandIndices {
                    state[bodies[index].id] = 0
                    if bodies[index].isSleeping {
                        bodies[index].wake()
                        events.append(SleepingEvent(phase: .ended, body: bodies[index].id))
                    }
                }
                continue
            }

            var priorQuietTime = configuration.minimumQuietTime
            for body in island.bodyIDs {
                priorQuietTime = min(priorQuietTime, state[body])
            }
            let quietTime = min(priorQuietTime + timeStep, configuration.minimumQuietTime)
            for index in islandIndices {
                state[bodies[index].id] = quietTime
                if quietTime >= configuration.minimumQuietTime, !bodies[index].isSleeping {
                    bodies[index].setSleeping(true)
                    events.append(SleepingEvent(phase: .started, body: bodies[index].id))
                }
            }
        }
        world.replaceBodies(bodies)
        state.recordSleepingBodies(in: bodies)
        return events
    }
}
