/// A Metal-first fixed-timestep physics engine.
///
/// An engine serializes access to its ``World`` and never silently switches to
/// the CPU reference integrator. Constructing it or stepping it surfaces
/// ``MetalBackendError`` when Metal cannot perform the requested work.
public actor Engine {
    private var world: World
    private let backend: MetalBackend
    public let gravity: Vector
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

    /// Runs one or more fixed Metal simulation ticks and returns the resulting snapshot.
    public func step(ticks: Int = 1) async throws -> World {
        guard ticks > 0 else {
            throw MatterError.invalidTickCount
        }

        for _ in 0 ..< ticks {
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
