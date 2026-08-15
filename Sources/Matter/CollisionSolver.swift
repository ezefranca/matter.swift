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
        try configuration.validate()
        let initialCollisions = CollisionDetector.collisions(in: world)
        var bodies = world.bodies

        for _ in 0..<configuration.velocityIterations {
            for collision in initialCollisions where !collision.isSensor {
                resolveVelocity(
                    collision,
                    bodies: &bodies,
                    restitutionThreshold: configuration.restitutionVelocityThreshold
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

    static func resolveVelocity(
        _ collision: Collision,
        bodies: inout [Body],
        restitutionThreshold: Float
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
            guard normalSpeed <= 0 else { continue }

            let restitution =
                abs(normalSpeed) < restitutionThreshold
                ? 0 : max(bodyA.restitution, bodyB.restitution)
            let normalMass = effectiveMass(
                bodyA,
                radius: radiusA,
                bodyB,
                radius: radiusB,
                direction: collision.normal
            )
            let normalMagnitude =
                -(1 + restitution) * normalSpeed
                / (normalMass * Float(collision.contacts.count))
            let normalImpulse = collision.normal * normalMagnitude
            bodyA.applyImpulse(-normalImpulse, at: contact.position)
            bodyB.applyImpulse(normalImpulse, at: contact.position)

            relativeVelocity =
                velocity(at: radiusB, on: bodyB)
                - velocity(at: radiusA, on: bodyA)
            let tangentVelocity =
                relativeVelocity
                - collision.normal * relativeVelocity.dot(collision.normal)
            guard tangentVelocity.lengthSquared > velocityTolerance else { continue }

            let tangent = tangentVelocity.normalized()
            let tangentMass = effectiveMass(
                bodyA,
                radius: radiusA,
                bodyB,
                radius: radiusB,
                direction: tangent
            )
            let unconstrainedMagnitude =
                -relativeVelocity.dot(tangent)
                / (tangentMass * Float(collision.contacts.count))
            let staticFriction =
                (bodyA.staticFriction * bodyB.staticFriction).squareRoot()
            let dynamicFriction = (bodyA.friction * bodyB.friction).squareRoot()
            let frictionMagnitude: Float
            if abs(unconstrainedMagnitude) <= normalMagnitude * staticFriction {
                frictionMagnitude = unconstrainedMagnitude
            } else {
                frictionMagnitude = -normalMagnitude * dynamicFriction
            }
            let frictionImpulse = tangent * frictionMagnitude
            bodyA.applyImpulse(-frictionImpulse, at: contact.position)
            bodyB.applyImpulse(frictionImpulse, at: contact.position)
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
