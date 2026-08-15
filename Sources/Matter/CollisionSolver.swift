import Foundation

/// Iteration counts and stability thresholds for discrete collision response.
@frozen
public struct SolverConfiguration: Sendable, Hashable, Codable {
    /// Sequential impulse passes applied to contact velocities.
    public var velocityIterations: Int

    /// Positional correction passes applied to penetrations.
    public var positionIterations: Int

    /// Fraction of excess penetration corrected per position pass, in `0...1`.
    public var positionCorrection: Float

    /// Normal speeds below this value do not apply restitution.
    public var restitutionVelocityThreshold: Float

    /// Creates solver tuning that is validated when a solver or engine uses it.
    public init(
        velocityIterations: Int = 8,
        positionIterations: Int = 3,
        positionCorrection: Float = 0.8,
        restitutionVelocityThreshold: Float = 1
    ) {
        self.velocityIterations = velocityIterations
        self.positionIterations = positionIterations
        self.positionCorrection = positionCorrection
        self.restitutionVelocityThreshold = restitutionVelocityThreshold
    }

    /// Stable defaults suitable for ordinary real-time worlds.
    public static let standard = Self()

    func validate() throws {
        guard
            velocityIterations > 0,
            positionIterations > 0,
            positionCorrection.isFinite,
            restitutionVelocityThreshold.isFinite,
            (0...1).contains(positionCorrection),
            restitutionVelocityThreshold >= 0
        else {
            throw MatterError.invalidSolverConfiguration
        }
    }
}

/// A stable collision pair and primitive contact feature.
@frozen
public struct ContactKey: Sendable, Hashable, Codable, Comparable {
    /// The canonical bodies owning the contact.
    public let pair: BodyPair

    /// The primitive-part and manifold indices within the pair.
    public let featureID: ContactFeatureID

    /// Creates a key from a detected collision pair and contact feature.
    public init(pair: BodyPair, featureID: ContactFeatureID) {
        self.pair = pair
        self.featureID = featureID
    }

    /// Orders keys by body pair and then feature identity.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.pair == rhs.pair ? lhs.featureID < rhs.featureID : lhs.pair < rhs.pair
    }
}

/// Accumulated normal and tangent impulses for one persistent contact.
@frozen
public struct ContactImpulse: Sendable, Hashable, Codable {
    /// Nonnegative impulse magnitude along the collision normal.
    public let normal: Float

    /// Signed impulse magnitude along the normal's counterclockwise tangent.
    public let tangent: Float

    init(normal: Float, tangent: Float) {
        self.normal = normal
        self.tangent = tangent
    }

    static let zero = Self(normal: 0, tangent: 0)
}

/// Value-semantic persistent contact state used for warm starting.
@frozen
public struct CollisionSolverState: Sendable, Hashable, Codable {
    private var impulses: [ContactKey: ContactImpulse]

    /// Creates an empty cache whose first solve starts cold.
    public init() {
        impulses = [:]
    }

    /// Active cached contacts in stable key order.
    public var activeContacts: [ContactKey] {
        impulses.keys.sorted()
    }

    /// The number of contacts retained from the most recent solve.
    public var contactCount: Int {
        impulses.count
    }

    /// Returns the accumulated impulse for a contact, when it remains active.
    public func impulse(for key: ContactKey) -> ContactImpulse? {
        impulses[key]
    }

    /// Removes every cached contact so the next solve starts cold.
    public mutating func reset() {
        impulses.removeAll(keepingCapacity: true)
    }

    subscript(key: ContactKey) -> ContactImpulse? {
        get { impulses[key] }
        set { impulses[key] = newValue }
    }

    mutating func retain(_ keys: Set<ContactKey>) {
        impulses = impulses.filter { keys.contains($0.key) }
    }
}

/// Deterministic sequential-impulse collision response.
///
/// The solver mutates a value-semantic ``World`` synchronously on the caller's
/// executor. Sensors are reported but never receive impulses or corrections.
@frozen
public enum CollisionSolver {
    /// Resolves the world's current discrete collisions.
    ///
    /// - Parameters:
    ///   - world: The world to mutate in place.
    ///   - configuration: Validated iteration and stability tuning.
    /// - Returns: Collisions detected before positional correction.
    /// - Throws: ``MatterError/invalidSolverConfiguration`` when iteration
    ///   counts or numerical thresholds are invalid.
    @discardableResult
    public static func resolve(
        world: inout World,
        configuration: SolverConfiguration = .standard
    ) throws -> [Collision] {
        var state = CollisionSolverState()
        return try resolve(world: &world, state: &state, configuration: configuration)
    }

    /// Resolves collisions and persists accumulated impulses for warm starting.
    ///
    /// The state prunes ended and sensor contacts after every solve. Reuse the
    /// same value across fixed ticks; call ``CollisionSolverState/reset()`` after
    /// an unrelated world replacement.
    @discardableResult
    public static func resolve(
        world: inout World,
        state: inout CollisionSolverState,
        configuration: SolverConfiguration = .standard
    ) throws -> [Collision] {
        try configuration.validate()
        let initialCollisions = CollisionDetector.collisions(in: world)
        var bodies = world.bodies
        let activeKeys = Set(
            initialCollisions.lazy.filter { !$0.isSensor }.flatMap { collision in
                collision.contacts.map {
                    ContactKey(pair: collision.pair, featureID: $0.featureID)
                }
            }
        )
        state.retain(activeKeys)
        let restitutionTargets = restitutionTargets(
            initialCollisions,
            bodies: bodies,
            threshold: configuration.restitutionVelocityThreshold
        )
        warmStart(initialCollisions, bodies: &bodies, state: state)

        for _ in 0..<configuration.velocityIterations {
            for collision in initialCollisions where !collision.isSensor {
                resolveVelocity(
                    collision,
                    bodies: &bodies,
                    restitutionTargets: restitutionTargets,
                    state: &state
                )
            }
        }

        world.replaceBodies(bodies)
        for _ in 0..<configuration.positionIterations {
            let collisions = CollisionDetector.collisions(in: world)
            bodies = world.bodies
            for collision in collisions where !collision.isSensor {
                resolvePosition(
                    collision,
                    bodies: &bodies,
                    correctionFraction: configuration.positionCorrection
                        / Float(configuration.positionIterations)
                )
            }
            world.replaceBodies(bodies)
        }
        return initialCollisions
    }
}

private extension CollisionSolver {
    static let velocityTolerance: Float = 0.000_001

    static func restitutionTargets(
        _ collisions: [Collision],
        bodies: [Body],
        threshold: Float
    ) -> [ContactKey: Float] {
        var targets: [ContactKey: Float] = [:]
        for collision in collisions where !collision.isSensor {
            let indices = bodyIndices(for: collision.pair, in: bodies)
            let bodyA = bodies[indices.first]
            let bodyB = bodies[indices.second]
            for contact in collision.contacts {
                let radiusA = contact.position - bodyA.position
                let radiusB = contact.position - bodyB.position
                let relativeVelocity =
                    velocity(at: radiusB, on: bodyB)
                    - velocity(at: radiusA, on: bodyA)
                let normalSpeed = relativeVelocity.dot(collision.normal)
                guard normalSpeed < -threshold else { continue }
                let key = ContactKey(pair: collision.pair, featureID: contact.featureID)
                targets[key] = -max(bodyA.restitution, bodyB.restitution) * normalSpeed
            }
        }
        return targets
    }

    static func warmStart(
        _ collisions: [Collision],
        bodies: inout [Body],
        state: CollisionSolverState
    ) {
        for collision in collisions where !collision.isSensor {
            let indices = bodyIndices(for: collision.pair, in: bodies)
            var bodyA = bodies[indices.first]
            var bodyB = bodies[indices.second]
            guard bodyA.inverseMass + bodyB.inverseMass > 0 else { continue }
            let tangent = Vector(x: -collision.normal.y, y: collision.normal.x)
            for contact in collision.contacts {
                let key = ContactKey(pair: collision.pair, featureID: contact.featureID)
                guard let cached = state.impulse(for: key) else { continue }
                let impulse = collision.normal * cached.normal + tangent * cached.tangent
                bodyA.applyImpulse(-impulse, at: contact.position)
                bodyB.applyImpulse(impulse, at: contact.position)
            }
            bodies[indices.first] = bodyA
            bodies[indices.second] = bodyB
        }
    }

    static func resolveVelocity(
        _ collision: Collision,
        bodies: inout [Body],
        restitutionTargets: [ContactKey: Float],
        state: inout CollisionSolverState
    ) {
        let indices = bodyIndices(for: collision.pair, in: bodies)
        var bodyA = bodies[indices.first]
        var bodyB = bodies[indices.second]
        guard bodyA.inverseMass + bodyB.inverseMass > 0 else { return }

        for contact in collision.contacts {
            let radiusA = contact.position - bodyA.position
            let radiusB = contact.position - bodyB.position
            var relativeVelocity =
                velocity(at: radiusB, on: bodyB)
                - velocity(at: radiusA, on: bodyA)
            let normalSpeed = relativeVelocity.dot(collision.normal)
            let normalMass = effectiveMass(
                bodyA,
                radius: radiusA,
                bodyB,
                radius: radiusB,
                direction: collision.normal
            )
            let key = ContactKey(pair: collision.pair, featureID: contact.featureID)
            let previous = state[key] ?? .zero
            let normalDelta =
                ((restitutionTargets[key] ?? 0) - normalSpeed)
                / (normalMass * Float(collision.contacts.count))
            let normalMagnitude = max(previous.normal + normalDelta, 0)
            let normalImpulse = collision.normal * (normalMagnitude - previous.normal)
            bodyA.applyImpulse(-normalImpulse, at: contact.position)
            bodyB.applyImpulse(normalImpulse, at: contact.position)

            relativeVelocity =
                velocity(at: radiusB, on: bodyB)
                - velocity(at: radiusA, on: bodyA)
            let tangent = Vector(x: -collision.normal.y, y: collision.normal.x)
            let tangentMass = effectiveMass(
                bodyA,
                radius: radiusA,
                bodyB,
                radius: radiusB,
                direction: tangent
            )
            let tangentDelta =
                -relativeVelocity.dot(tangent)
                / (tangentMass * Float(collision.contacts.count))
            let staticFriction =
                (bodyA.staticFriction * bodyB.staticFriction).squareRoot()
            let dynamicFriction = (bodyA.friction * bodyB.friction).squareRoot()
            let candidateTangent = previous.tangent + tangentDelta
            let staticLimit = normalMagnitude * staticFriction
            let tangentMagnitude: Float
            if abs(candidateTangent) <= staticLimit {
                tangentMagnitude = candidateTangent
            } else {
                let dynamicLimit = normalMagnitude * dynamicFriction
                tangentMagnitude = min(max(candidateTangent, -dynamicLimit), dynamicLimit)
            }
            let frictionImpulse = tangent * (tangentMagnitude - previous.tangent)
            bodyA.applyImpulse(-frictionImpulse, at: contact.position)
            bodyB.applyImpulse(frictionImpulse, at: contact.position)
            let impulse = ContactImpulse(normal: normalMagnitude, tangent: tangentMagnitude)
            state[key] =
                impulse.normal > velocityTolerance || abs(impulse.tangent) > velocityTolerance
                ? impulse : nil
        }

        bodies[indices.first] = bodyA
        bodies[indices.second] = bodyB
    }

    static func resolvePosition(
        _ collision: Collision,
        bodies: inout [Body],
        correctionFraction: Float
    ) {
        let indices = bodyIndices(for: collision.pair, in: bodies)
        var bodyA = bodies[indices.first]
        var bodyB = bodies[indices.second]
        let inverseMass = bodyA.inverseMass + bodyB.inverseMass
        guard inverseMass > 0 else { return }

        let slop = max(bodyA.slop, bodyB.slop)
        let correctionMagnitude =
            max(collision.penetration - slop, 0)
            * correctionFraction / inverseMass
        guard correctionMagnitude > 0 else { return }
        let correction = collision.normal * correctionMagnitude
        bodyA.applyPositionCorrection(-correction * bodyA.inverseMass)
        bodyB.applyPositionCorrection(correction * bodyB.inverseMass)
        bodies[indices.first] = bodyA
        bodies[indices.second] = bodyB
    }

    static func bodyIndices(
        for pair: BodyPair,
        in bodies: [Body]
    ) -> (first: Int, second: Int) {
        let indices = bodies.indices
            .filter { bodies[$0].id == pair.first || bodies[$0].id == pair.second }
            .sorted { bodies[$0].id < bodies[$1].id }
        return (indices[0], indices[1])
    }

    static func velocity(at radius: Vector, on body: Body) -> Vector {
        body.velocity
            + Vector(
                x: -body.angularVelocity * radius.y,
                y: body.angularVelocity * radius.x
            )
    }

    static func effectiveMass(
        _ bodyA: Body,
        radius radiusA: Vector,
        _ bodyB: Body,
        radius radiusB: Vector,
        direction: Vector
    ) -> Float {
        let angularA = radiusA.cross(direction)
        let angularB = radiusB.cross(direction)
        return bodyA.inverseMass + bodyB.inverseMass
            + angularA * angularA * bodyA.inverseInertia
            + angularB * angularB * bodyB.inverseInertia
    }
}
