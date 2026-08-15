/// Errors emitted while creating or simulating Matter values.
@frozen
public enum MatterError: Error, Sendable, Equatable {
    /// A body mass was nonfinite or not greater than zero.
    case invalidMass
    /// A shape dimension was nonfinite or not greater than zero.
    case invalidShapeDimension
    /// A simulation time step was nonfinite or not greater than zero.
    case invalidTimeStep
    /// An engine was asked to perform fewer than one tick.
    case invalidTickCount
    /// A mutation referenced an identifier absent from the world.
    case unknownBody(BodyID)
    /// The world's monotonically increasing identifier sequence reached `UInt64.max`.
    case bodyIdentifierExhausted
}

/// Owns a collection of value-type bodies and their identifiers.
@frozen
public struct World: Sendable, Hashable, Codable {
    /// Value snapshots of the bodies in deterministic insertion order.
    public private(set) var bodies: [Body]
    private var nextBodyIdentifier: UInt64

    /// Creates an empty world whose first assigned body identifier is one.
    public init() {
        self.bodies = []
        self.nextBodyIdentifier = 0
    }

    /// Adds a body and assigns its stable identifier.
    @discardableResult
    public mutating func add(_ definition: BodyDefinition) throws -> BodyID {
        guard nextBodyIdentifier < .max else {
            throw MatterError.bodyIdentifierExhausted
        }

        nextBodyIdentifier += 1
        let identifier = BodyID(rawValue: nextBodyIdentifier)
        bodies.append(Body(id: identifier, definition: definition))
        return identifier
    }

    /// Returns the body with a stable identifier, or `nil` when it is absent.
    public func body(withID identifier: BodyID) -> Body? {
        bodies.first { $0.id == identifier }
    }

    /// Applies a force that the next simulation tick consumes.
    public mutating func applyForce(_ force: Vector, to identifier: BodyID) throws {
        guard let index = bodies.firstIndex(where: { $0.id == identifier }) else {
            throw MatterError.unknownBody(identifier)
        }

        bodies[index].applyForce(force)
    }

    mutating func replaceBodies(_ bodies: [Body]) {
        self.bodies = bodies
    }
}

/// Deterministic CPU integration for reference implementations and tests.
///
/// ``Engine`` deliberately does not use this type as a fallback: production
/// simulation requires a functioning Metal backend.
public enum ReferenceIntegrator {
    /// Advances every world body using semi-implicit Euler integration.
    public static func step(
        world: inout World,
        gravity: Vector,
        timeStep: Float
    ) throws {
        guard timeStep.isFinite, timeStep > 0 else {
            throw MatterError.invalidTimeStep
        }

        var bodies = world.bodies
        for index in bodies.indices {
            step(body: &bodies[index], gravity: gravity, timeStep: timeStep)
        }
        world.replaceBodies(bodies)
    }

    /// Advances one body using semi-implicit Euler integration.
    public static func step(body: inout Body, gravity: Vector, timeStep: Float) {
        guard !body.isStatic else {
            body.clearForce()
            return
        }

        let acceleration = gravity + (body.force * body.inverseMass)
        body.velocity += acceleration * timeStep
        body.position += body.velocity * timeStep
        body.clearForce()
    }
}
