import Foundation

/// Iteration counts for deterministic distance-constraint solving.
@frozen
public struct ConstraintSolverConfiguration: Sendable, Hashable, Codable {
    /// Sequential damping passes applied to anchor velocities.
    public var velocityIterations: Int

    /// Sequential correction passes applied to anchor positions and angles.
    public var positionIterations: Int

    /// Creates tuning that is validated when a solver or engine uses it.
    public init(velocityIterations: Int = 2, positionIterations: Int = 4) {
        self.velocityIterations = velocityIterations
        self.positionIterations = positionIterations
    }

    /// Stable defaults suitable for ordinary real-time worlds.
    public static let standard = Self()

    func validate() throws {
        guard velocityIterations > 0, positionIterations > 0 else {
            throw MatterError.invalidConstraintSolverConfiguration
        }
    }
}

/// Deterministic sequential solver for world distance constraints.
@frozen
public enum ConstraintSolver {
    /// Resolves constraints and removes any whose impulse limit is exceeded.
    ///
    /// - Returns: Broken constraint identifiers in stable world order.
    /// - Throws: Invalid time-step or solver configuration errors, or
    ///   ``MatterError/unknownBody(_:)`` for corrupt external snapshots.
    @discardableResult
    public static func resolve(
        world: inout World,
        timeStep: Float,
        configuration: ConstraintSolverConfiguration = .standard
    ) throws -> [ConstraintID] {
        guard timeStep.isFinite, timeStep > 0 else {
            throw MatterError.invalidTimeStep
        }
        try configuration.validate()

        var active: [Constraint] = []
        var broken: [ConstraintID] = []
        for constraint in world.constraints {
            if try exceedsBreakLimit(constraint, bodies: world.bodies, timeStep: timeStep) {
                broken.append(constraint.id)
            } else {
                active.append(constraint)
            }
        }
        world.replaceConstraints(active)

        var bodies = world.bodies
        for _ in 0..<configuration.velocityIterations {
            for constraint in active {
                try resolveVelocity(constraint, bodies: &bodies)
            }
        }
        for _ in 0..<configuration.positionIterations {
            for constraint in active {
                try resolvePosition(constraint, bodies: &bodies)
            }
        }
        world.replaceBodies(bodies)
        return broken
    }
}

private extension ConstraintSolver {
    struct Endpoint {
        let bodyIndex: Int?
        let point: Vector
        let radius: Vector
        let angle: Float
        let inverseMass: Float
        let inverseInertia: Float
    }

    static let tolerance: Float = 0.000_001

    static func exceedsBreakLimit(
        _ constraint: Constraint,
        bodies: [Body],
        timeStep: Float
    ) throws -> Bool {
        guard let maximumImpulse = constraint.maximumImpulse else { return false }
        let endpoints = try resolveEndpoints(constraint, bodies: bodies)
        let delta = endpoints.second.point - endpoints.first.point
        let direction = direction(for: delta)
        let mass = effectiveMass(endpoints, direction: direction)
        let distanceImpulse =
            mass > tolerance
            ? abs(delta.length - constraint.length) * constraint.stiffness / (mass * timeStep)
            : 0
        let angularMass = endpoints.first.inverseInertia + endpoints.second.inverseInertia
        let angularImpulse =
            angularMass > tolerance
            ? abs(angularError(constraint, endpoints: endpoints, bodies: bodies))
                * constraint.angularStiffness / (angularMass * timeStep)
            : 0
        return max(distanceImpulse, angularImpulse) > maximumImpulse
    }

    static func resolveVelocity(_ constraint: Constraint, bodies: inout [Body]) throws {
        guard constraint.damping > 0 else { return }
        let endpoints = try resolveEndpoints(constraint, bodies: bodies)
        let direction = direction(for: endpoints.second.point - endpoints.first.point)
        let mass = effectiveMass(endpoints, direction: direction)
        if mass > tolerance {
            let relativeVelocity =
                velocity(of: endpoints.second, bodies: bodies)
                - velocity(of: endpoints.first, bodies: bodies)
            let impulse = direction * (relativeVelocity.dot(direction) * constraint.damping / mass)
            applyVelocityImpulse(impulse, to: endpoints.first, bodies: &bodies)
            applyVelocityImpulse(-impulse, to: endpoints.second, bodies: &bodies)
        }
        resolveAngularVelocity(constraint, endpoints: endpoints, bodies: &bodies)
    }

    static func resolvePosition(_ constraint: Constraint, bodies: inout [Body]) throws {
        let endpoints = try resolveEndpoints(constraint, bodies: bodies)
        let delta = endpoints.second.point - endpoints.first.point
        let direction = direction(for: delta)
        let mass = effectiveMass(endpoints, direction: direction)
        let error = delta.length - constraint.length
        if mass > tolerance, abs(error) > tolerance, constraint.stiffness > 0 {
            let impulse = direction * (error * constraint.stiffness / mass)
            applyPositionImpulse(impulse, to: endpoints.first, bodies: &bodies)
            applyPositionImpulse(-impulse, to: endpoints.second, bodies: &bodies)
        }
        resolveAngularPosition(constraint, endpoints: endpoints, bodies: &bodies)
    }

    static func resolveAngularVelocity(
        _ constraint: Constraint,
        endpoints: (first: Endpoint, second: Endpoint),
        bodies: inout [Body]
    ) {
        let mass = endpoints.first.inverseInertia + endpoints.second.inverseInertia
        guard mass > tolerance else { return }
        let firstVelocity = endpoints.first.bodyIndex.map { bodies[$0].angularVelocity } ?? 0
        let secondVelocity = endpoints.second.bodyIndex.map { bodies[$0].angularVelocity } ?? 0
        let relativeVelocity: Float
        if endpoints.first.bodyIndex != nil, endpoints.second.bodyIndex != nil {
            relativeVelocity = secondVelocity - firstVelocity
        } else {
            relativeVelocity = firstVelocity + secondVelocity
        }
        let impulse = relativeVelocity * constraint.damping / mass
        if let index = endpoints.first.bodyIndex {
            bodies[index].applyAngularImpulse(impulse)
        }
        if let index = endpoints.second.bodyIndex {
            bodies[index].applyAngularImpulse(-impulse)
        }
    }

    static func resolveAngularPosition(
        _ constraint: Constraint,
        endpoints: (first: Endpoint, second: Endpoint),
        bodies: inout [Body]
    ) {
        guard constraint.angularStiffness > 0 else { return }
        let mass = endpoints.first.inverseInertia + endpoints.second.inverseInertia
        guard mass > tolerance else { return }
        let impulse =
            angularError(constraint, endpoints: endpoints, bodies: bodies)
            * constraint.angularStiffness / mass
        if let index = endpoints.first.bodyIndex {
            bodies[index].applyAngularPositionImpulse(impulse)
        }
        if let index = endpoints.second.bodyIndex {
            bodies[index].applyAngularPositionImpulse(-impulse)
        }
    }

    static func angularError(
        _ constraint: Constraint,
        endpoints: (first: Endpoint, second: Endpoint),
        bodies: [Body]
    ) -> Float {
        let current: Float
        if endpoints.first.bodyIndex != nil, endpoints.second.bodyIndex != nil {
            current = endpoints.second.angle - endpoints.first.angle
        } else {
            current = endpoints.first.angle + endpoints.second.angle
        }
        return normalizedAngle(current - constraint.referenceAngle)
    }

    static func resolveEndpoints(
        _ constraint: Constraint,
        bodies: [Body]
    ) throws -> (first: Endpoint, second: Endpoint) {
        (
            try resolve(constraint.first, bodies: bodies),
            try resolve(constraint.second, bodies: bodies)
        )
    }

    static func resolve(_ anchor: ConstraintAnchor, bodies: [Body]) throws -> Endpoint {
        switch anchor {
        case let .fixed(point):
            return Endpoint(
                bodyIndex: nil,
                point: point,
                radius: .zero,
                angle: 0,
                inverseMass: 0,
                inverseInertia: 0
            )
        case let .body(identifier, local):
            guard let index = bodies.firstIndex(where: { $0.id == identifier }) else {
                throw MatterError.unknownBody(identifier)
            }
            let body = bodies[index]
            let radius = local.rotated(by: body.angle)
            return Endpoint(
                bodyIndex: index,
                point: body.position + radius,
                radius: radius,
                angle: body.angle,
                inverseMass: body.inverseMass,
                inverseInertia: body.inverseInertia
            )
        }
    }

    static func direction(for delta: Vector) -> Vector {
        delta.lengthSquared > tolerance ? delta.normalized() : Vector(x: 1, y: 0)
    }

    static func effectiveMass(
        _ endpoints: (first: Endpoint, second: Endpoint),
        direction: Vector
    ) -> Float {
        let angularFirst = endpoints.first.radius.cross(direction)
        let angularSecond = endpoints.second.radius.cross(direction)
        return endpoints.first.inverseMass + endpoints.second.inverseMass
            + angularFirst * angularFirst * endpoints.first.inverseInertia
            + angularSecond * angularSecond * endpoints.second.inverseInertia
    }

    static func velocity(of endpoint: Endpoint, bodies: [Body]) -> Vector {
        guard let index = endpoint.bodyIndex else { return .zero }
        let body = bodies[index]
        return body.velocity
            + Vector(
                x: -body.angularVelocity * endpoint.radius.y,
                y: body.angularVelocity * endpoint.radius.x
            )
    }

    static func applyVelocityImpulse(
        _ impulse: Vector,
        to endpoint: Endpoint,
        bodies: inout [Body]
    ) {
        guard let index = endpoint.bodyIndex else { return }
        bodies[index].applyImpulse(impulse, at: endpoint.point)
    }

    static func applyPositionImpulse(
        _ impulse: Vector,
        to endpoint: Endpoint,
        bodies: inout [Body]
    ) {
        guard let index = endpoint.bodyIndex else { return }
        bodies[index].applyPositionImpulse(impulse, at: endpoint.point)
    }

    static func normalizedAngle(_ angle: Float) -> Float {
        atan2(sin(angle), cos(angle))
    }
}
