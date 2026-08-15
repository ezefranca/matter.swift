/// A Metal-first fixed-timestep physics engine.
///
/// An engine serializes access to its ``World`` and never silently switches to
/// the CPU reference integrator. Constructing it or stepping it surfaces
/// ``MetalBackendError`` when Metal cannot perform the requested work.
public actor Engine {
    private var world: World
    private let backend: MetalBackend
    /// The constant acceleration applied to every dynamic body each tick.
    public let gravity: Vector
    /// The finite, positive duration of one deterministic simulation tick.
    public let fixedTimeStep: Float

    /// Creates an engine backed by Metal.
    public init(
        world: World = .init(),
        gravity: Vector = Vector(x: 0, y: 9.81),
        fixedTimeStep: Float = 1.0 / 60.0
    ) throws {
        guard fixedTimeStep.isFinite, fixedTimeStep > 0 else {
            throw MatterError.invalidTimeStep
        }

        self.world = world
        self.gravity = gravity
        self.fixedTimeStep = fixedTimeStep
        self.backend = try MetalBackend()
    }

    /// Returns an immutable snapshot of the world at this instant.
    public func snapshot() -> World {
        world
    }

    /// Adds a body to the actor-owned world.
    @discardableResult
    public func add(_ definition: BodyDefinition) throws -> BodyID {
        try world.add(definition)
    }

    /// Accumulates a force for the next fixed simulation tick.
    public func applyForce(_ force: Vector, to body: BodyID) throws {
        try world.applyForce(force, to: body)
    }

    /// Accumulates force and torque by applying force at a world-space point.
    public func applyForce(_ force: Vector, at point: Vector, to body: BodyID) throws {
        try world.applyForce(force, at: point, to: body)
    }

    /// Accumulates torque for the next fixed simulation tick.
    public func applyTorque(_ torque: Float, to body: BodyID) throws {
        try world.applyTorque(torque, to: body)
    }

    /// Mutates one actor-owned body using a synchronous value closure.
    public func updateBody(
        withID identifier: BodyID,
        _ update: @Sendable (inout Body) throws -> Void
    ) throws {
        try world.updateBody(withID: identifier, update)
    }

    /// Removes and returns an actor-owned body when it exists.
    @discardableResult
    public func removeBody(withID identifier: BodyID) -> Body? {
        world.removeBody(withID: identifier)
    }

    /// Runs one or more fixed Metal simulation ticks and returns the resulting snapshot.
    public func step(ticks: Int = 1) async throws -> World {
        guard ticks > 0 else {
            throw MatterError.invalidTickCount
        }

        for _ in 0..<ticks {
            try Task.checkCancellation()
            let integrated = try await backend.integrate(
                bodies: world.bodies,
                gravity: gravity,
                timeStep: fixedTimeStep
            )
            world.replaceBodies(integrated)
        }

        return world
    }
}
