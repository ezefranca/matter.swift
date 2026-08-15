import Foundation

/// Selection and spring tuning for a ``MouseConstraint``.
@frozen
public struct MouseConstraintConfiguration: Sendable, Hashable, Codable {
    /// Positional correction strength per solver pass, in `0...1`.
    public var stiffness: Float

    /// Relative anchor velocity removed per solver pass, in `0...1`.
    public var damping: Float

    /// Relative body rotation corrected per solver pass, in `0...1`.
    public var angularStiffness: Float

    /// Which body collision categories the pointer may select.
    public var collisionFilter: CollisionFilter

    /// Whether fixed bodies may be selected in addition to dynamic bodies.
    public var includesStaticBodies: Bool

    /// Creates validated pointer-constraint tuning.
    ///
    /// - Throws: ``MatterError/invalidConstraint`` when a strength is nonfinite
    ///   or outside `0...1`, or ``MatterError/invalidCollisionFilter`` when the
    ///   selection category is zero.
    public init(
        stiffness: Float = 0.2,
        damping: Float = 0.1,
        angularStiffness: Float = 0,
        collisionFilter: CollisionFilter = .all,
        includesStaticBodies: Bool = false
    ) throws {
        self.stiffness = stiffness
        self.damping = damping
        self.angularStiffness = angularStiffness
        self.collisionFilter = collisionFilter
        self.includesStaticBodies = includesStaticBodies
        try validate()
    }

    /// Stable defaults for dragging dynamic bodies with a compliant spring.
    public static let standard = Self(
        uncheckedStiffness: 0.2,
        damping: 0.1,
        angularStiffness: 0,
        collisionFilter: .all,
        includesStaticBodies: false
    )

    private init(
        uncheckedStiffness stiffness: Float,
        damping: Float,
        angularStiffness: Float,
        collisionFilter: CollisionFilter,
        includesStaticBodies: Bool
    ) {
        self.stiffness = stiffness
        self.damping = damping
        self.angularStiffness = angularStiffness
        self.collisionFilter = collisionFilter
        self.includesStaticBodies = includesStaticBodies
    }

    func validate() throws {
        guard
            stiffness.isFinite,
            damping.isFinite,
            angularStiffness.isFinite,
            (0...1).contains(stiffness),
            (0...1).contains(damping),
            (0...1).contains(angularStiffness)
        else {
            throw MatterError.invalidConstraint
        }
        try collisionFilter.validate()
    }
}

/// Platform-neutral pointer dragging backed by a transient distance constraint.
///
/// The value stores identifiers rather than references, so it is safe to copy,
/// serialize, and move across actors with a ``World`` snapshot. Coordinates use
/// Matter world space. On Apple platforms, create them directly from a P5
/// pointer location with `try Vector(event.location)`.
@frozen
public struct MouseConstraint: Sendable, Hashable, Codable {
    /// The current pointer position in world coordinates.
    public private(set) var point: Vector

    /// The selected body while a drag is active.
    public private(set) var bodyID: BodyID?

    /// The transient world constraint while a drag is active.
    public private(set) var constraintID: ConstraintID?

    /// Selection and solver tuning used by the next press.
    public var configuration: MouseConstraintConfiguration

    /// Whether this value currently owns a transient world constraint.
    public var isActive: Bool {
        bodyID != nil && constraintID != nil
    }

    /// Creates an inactive pointer constraint at a finite world point.
    public init(
        point: Vector = .zero,
        configuration: MouseConstraintConfiguration = .standard
    ) throws {
        guard point.isFinite else { throw MatterError.invalidVector }
        try configuration.validate()
        self.point = point
        self.bodyID = nil
        self.constraintID = nil
        self.configuration = configuration
    }

    /// Selects the topmost eligible body and begins dragging its touched point.
    ///
    /// Topmost means the last eligible body in stable world insertion order.
    /// Pressing empty space ends an existing drag and returns `nil`. The world
    /// and this value remain unchanged if validation or insertion fails.
    @discardableResult
    public mutating func press(at point: Vector, in world: inout World) throws -> BodyID? {
        guard point.isFinite else { throw MatterError.invalidVector }
        try configuration.validate()
        let selected = try WorldQuery.bodies(at: point, in: world).last { body in
            (configuration.includesStaticBodies || !body.isStatic)
                && configuration.collisionFilter.allowsCollision(with: body.collisionFilter)
        }

        var candidate = world
        if let constraintID {
            candidate.removeConstraint(withID: constraintID)
        }
        guard let selected else {
            world = candidate
            self.point = point
            bodyID = nil
            constraintID = nil
            return nil
        }

        let localAnchor = (point - selected.position).rotated(by: -selected.angle)
        let definition = try ConstraintDefinition(
            first: .fixed(point),
            second: .body(selected.id, local: localAnchor),
            length: 0,
            stiffness: configuration.stiffness,
            damping: configuration.damping,
            angularStiffness: configuration.angularStiffness,
            label: "Mouse Constraint"
        )
        let identifier = try candidate.addConstraint(definition)
        world = candidate
        self.point = point
        bodyID = selected.id
        constraintID = identifier
        return selected.id
    }

    /// Moves the pointer and the active transient constraint's fixed endpoint.
    ///
    /// Moving an inactive value only records the point. If a client removed the
    /// active constraint independently, the world reports
    /// ``MatterError/unknownConstraint(_:)``.
    public mutating func move(to point: Vector, in world: inout World) throws {
        guard point.isFinite else { throw MatterError.invalidVector }
        if let constraintID {
            try world.setFixedPoint(point, forConstraintWithID: constraintID)
        }
        self.point = point
    }

    /// Ends the active drag and removes its transient world constraint.
    ///
    /// The last pointer point remains available after release. This operation is
    /// idempotent when the constraint was already removed independently.
    @discardableResult
    public mutating func release(in world: inout World) -> Constraint? {
        let removed = constraintID.flatMap { world.removeConstraint(withID: $0) }
        bodyID = nil
        constraintID = nil
        return removed
    }
}
