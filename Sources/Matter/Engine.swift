/// A Metal-integrated, fixed-timestep physics engine with CPU collision response.
///
/// An engine serializes access to its ``World`` and never silently switches to
/// the CPU reference integrator. Integration runs on Metal; collision detection
/// and response are explicitly CPU-owned phases. Constructing it or stepping it
/// surfaces ``MetalBackendError`` when Metal cannot perform the requested work.
public actor Engine {
    private var world: World
    private var collisionTracker: CollisionTracker
    private let backend: MetalBackend
    /// The constant acceleration applied to every dynamic body each tick.
    public let gravity: Vector
    /// The finite, positive duration of one deterministic simulation tick.
    public let fixedTimeStep: Float
    /// The validated CPU collision-response configuration used after Metal integration.
    public let solverConfiguration: SolverConfiguration

    /// Creates an engine backed by Metal.
    public init(
        world: World = .init(),
        gravity: Vector = Vector(x: 0, y: 9.81),
        fixedTimeStep: Float = 1.0 / 60.0,
        solverConfiguration: SolverConfiguration = .standard
    ) throws {
        guard fixedTimeStep.isFinite, fixedTimeStep > 0 else {
            throw MatterError.invalidTimeStep
        }
        try solverConfiguration.validate()

        self.world = world
        self.gravity = gravity
        self.fixedTimeStep = fixedTimeStep
        self.solverConfiguration = solverConfiguration
        self.collisionTracker = CollisionTracker()
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

    /// Adds validated bodies atomically and optionally assigns them to a composite.
    @discardableResult
    public func add(
        _ definitions: [BodyDefinition],
        to composite: CompositeID? = nil
    ) throws -> [BodyID] {
        try world.add(definitions, to: composite)
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

    /// Mutates multiple actor-owned bodies atomically in one actor round trip.
    public func updateBodies(
        withIDs identifiers: [BodyID],
        _ update: @Sendable (inout Body) throws -> Void
    ) throws {
        try world.updateBodies(withIDs: identifiers, update)
    }

    /// Applies an arbitrary transactional mutation in one actor round trip.
    ///
    /// If the closure throws, the actor-owned world remains unchanged.
    public func updateWorld(
        _ update: @Sendable (inout World) throws -> Void
    ) throws {
        var candidate = world
        try update(&candidate)
        world = candidate
    }

    /// Removes and returns an actor-owned body when it exists.
    @discardableResult
    public func removeBody(withID identifier: BodyID) -> Body? {
        world.removeBody(withID: identifier)
    }

    /// Removes multiple actor-owned bodies atomically.
    @discardableResult
    public func removeBodies(withIDs identifiers: [BodyID]) throws -> [Body] {
        try world.removeBodies(withIDs: identifiers)
    }

    /// Adds a composite to the actor-owned world hierarchy.
    @discardableResult
    public func addComposite(
        label: String = "Composite",
        metadata: [String: String] = [:],
        parent: CompositeID? = nil
    ) throws -> CompositeID {
        try world.addComposite(label: label, metadata: metadata, parent: parent)
    }

    /// Assigns an actor-owned body directly to a composite.
    public func assignBody(_ body: BodyID, to composite: CompositeID) throws {
        try world.assignBody(body, to: composite)
    }

    /// Moves a composite below a new parent.
    public func reparentComposite(_ composite: CompositeID, to parent: CompositeID?) throws {
        try world.reparentComposite(composite, to: parent)
    }

    /// Removes a composite hierarchy and optionally its assigned bodies.
    @discardableResult
    public func removeComposite(
        withID identifier: CompositeID,
        removeBodies: Bool = false
    ) throws -> [Composite] {
        try world.removeComposite(withID: identifier, removeBodies: removeBodies)
    }

    /// Replaces the actor-owned world and clears collision lifecycle state.
    public func reset(to world: World = .init()) {
        self.world = world
        collisionTracker.reset()
    }

    /// Runs one or more fixed Metal simulation ticks and returns the resulting snapshot.
    public func step(ticks: Int = 1) async throws -> World {
        try await stepWithEvents(ticks: ticks).world
    }

    /// Runs fixed ticks and returns world, collision, and lifecycle-event snapshots.
    ///
    /// - Throws: ``MatterError/invalidTickCount``, cancellation, or a Metal
    ///   integration failure.
    public func stepWithEvents(ticks: Int = 1) async throws -> SimulationResult {
        guard ticks > 0 else {
            throw MatterError.invalidTickCount
        }

        var collisionEvents: [CollisionEvent] = []
        var collisions: [Collision] = []
        for _ in 0..<ticks {
            try Task.checkCancellation()
            let integrated = try await backend.integrate(
                bodies: world.bodies,
                gravity: gravity,
                timeStep: fixedTimeStep
            )
            world.replaceBodies(integrated)
            collisions = try CollisionSolver.resolve(
                world: &world,
                configuration: solverConfiguration
            )
            collisionEvents.append(contentsOf: collisionTracker.update(with: collisions))
        }

        return SimulationResult(
            world: world,
            tickCount: ticks,
            collisions: collisions,
            collisionEvents: collisionEvents
        )
    }
}
