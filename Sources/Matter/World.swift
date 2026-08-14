/// Errors emitted while creating or simulating Matter values.
@frozen
public enum MatterError: Error, Sendable, Equatable {
    case invalidMass
    case invalidShapeDimension
    case invalidTimeStep
    case invalidTickCount
    case unknownBody(BodyID)
    case bodyIdentifierExhausted
}

/// Owns a collection of value-type bodies and their identifiers.
@frozen
public struct World: Sendable, Hashable, Codable {
    public private(set) var bodies: [Body]
    private var nextBodyIdentifier: UInt64

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
