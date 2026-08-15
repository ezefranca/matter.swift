/// Errors emitted while creating or simulating Matter values.
@frozen
public enum MatterError: Error, Sendable, Equatable {
    /// A body mass was nonfinite or not greater than zero.
    case invalidMass
    /// A shape dimension was nonfinite or not greater than zero.
    case invalidShapeDimension
    /// Polygon vertices were missing, nonfinite, collinear, or degenerate.
    case invalidPolygon
    /// A polygon was not convex.
    case nonConvexPolygon
    /// A position, velocity, force, or point contained a nonfinite component.
    case invalidVector
    /// An angle, angular velocity, or torque was nonfinite.
    case invalidAngle
    /// Restitution, friction, drag, or slop was outside its supported range.
    case invalidMaterial
    /// A collision category was zero.
    case invalidCollisionFilter
    /// A label was empty or had surrounding whitespace.
    case invalidLabel
    /// Client metadata contained an empty key or untrimmed value.
    case invalidMetadata
    /// A simulation time step was nonfinite or not greater than zero.
    case invalidTimeStep
    /// An engine was asked to perform fewer than one tick.
    case invalidTickCount
    /// A runner or accumulator catch-up limit was not positive.
    case invalidMaximumTicks
    /// Elapsed runner time was negative or nonfinite.
    case invalidElapsedTime
    /// Solver iterations or numerical tuning values were outside supported ranges.
    case invalidSolverConfiguration
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
        try definition.validate()
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
        guard force.isFinite else { throw MatterError.invalidVector }
        guard let index = bodies.firstIndex(where: { $0.id == identifier }) else {
            throw MatterError.unknownBody(identifier)
        }

        bodies[index].applyForce(force)
    }

    /// Applies a force at a world-space point, accumulating linear force and torque.
    public mutating func applyForce(
        _ force: Vector,
        at point: Vector,
        to identifier: BodyID
    ) throws {
        guard force.isFinite, point.isFinite else { throw MatterError.invalidVector }
        try updateBody(withID: identifier) { body in
            body.applyForce(force, at: point)
        }
    }

    /// Applies torque to a body for the next simulation tick.
    public mutating func applyTorque(_ torque: Float, to identifier: BodyID) throws {
        guard torque.isFinite else { throw MatterError.invalidAngle }
        try updateBody(withID: identifier) { body in
            body.applyTorque(torque)
        }
    }

    /// Mutates a body in place while preserving deterministic world ordering.
    public mutating func updateBody(
        withID identifier: BodyID,
        _ update: (inout Body) throws -> Void
    ) throws {
        guard let index = bodies.firstIndex(where: { $0.id == identifier }) else {
            throw MatterError.unknownBody(identifier)
        }
        try update(&bodies[index])
    }

    /// Removes and returns a body, or returns `nil` when its identifier is absent.
    @discardableResult
    public mutating func removeBody(withID identifier: BodyID) -> Body? {
        guard let index = bodies.firstIndex(where: { $0.id == identifier }) else {
            return nil
        }
        return bodies.remove(at: index)
    }

    /// Removes all bodies while keeping identifiers monotonic by default.
    public mutating func removeAllBodies(resetIdentifiers: Bool = false) {
        bodies.removeAll(keepingCapacity: true)
        if resetIdentifiers {
            nextBodyIdentifier = 0
        }
    }

    /// The number of bodies owned by the world.
    public var bodyCount: Int {
        bodies.count
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
        body.integrate(gravity: gravity, timeStep: timeStep)
    }
}

/// Deterministic CPU integration and collision response for tests and tooling.
///
/// Production ``Engine`` uses Metal for integration and the same
/// ``CollisionSolver`` for the explicitly CPU-owned response phase.
public enum ReferencePhysics {
    /// Integrates one tick and resolves its discrete collisions.
    ///
    /// - Returns: Collisions detected after integration and before positional
    ///   correction.
    /// - Throws: ``MatterError/invalidTimeStep`` or
    ///   ``MatterError/invalidSolverConfiguration`` for invalid tuning.
    @discardableResult
    public static func step(
        world: inout World,
        gravity: Vector,
        timeStep: Float,
        solver configuration: SolverConfiguration = .standard
    ) throws -> [Collision] {
        try ReferenceIntegrator.step(world: &world, gravity: gravity, timeStep: timeStep)
        return try CollisionSolver.resolve(world: &world, configuration: configuration)
    }
}
