/// The stable identity assigned to a body by a ``World``.
@frozen
public struct BodyID: RawRepresentable, Sendable, Hashable, Codable, Comparable {
    /// The stable unsigned value stored in serialized world state.
    public let rawValue: UInt64

    /// Creates an identifier from its stable serialized value.
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// Orders identifiers by their unsigned raw values.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A body shape supported by the first Matter vertical slice.
@frozen
public enum BodyShape: Sendable, Hashable, Codable {
    /// A circle with a finite radius greater than zero.
    case circle(radius: Float)
    /// An axis-aligned rectangle with finite width and height greater than zero.
    case rectangle(width: Float, height: Float)

    func validate() throws {
        switch self {
        case let .circle(radius):
            guard radius.isFinite, radius > 0 else {
                throw MatterError.invalidShapeDimension
            }
        case let .rectangle(width, height):
            guard width.isFinite, height.isFinite, width > 0, height > 0 else {
                throw MatterError.invalidShapeDimension
            }
        }
    }
}

/// The input used to add a new body to a ``World``.
///
/// Factories in ``Bodies`` create definitions so the world, rather than callers,
/// remains the single owner of body identifiers.
@frozen
public struct BodyDefinition: Sendable, Hashable, Codable {
    /// The validated collision geometry for the body.
    public var shape: BodyShape
    /// The initial center position in world coordinates.
    public var position: Vector
    /// The initial linear velocity in world units per second.
    public var velocity: Vector
    /// The finite mass greater than zero; static bodies retain it for serialization.
    public var mass: Float
    /// Whether integration ignores forces and leaves the body fixed.
    public var isStatic: Bool

    /// Creates a validated definition for insertion into a world.
    ///
    /// - Throws: ``MatterError/invalidShapeDimension`` or
    ///   ``MatterError/invalidMass`` when the definition is invalid.
    public init(
        shape: BodyShape,
        position: Vector,
        velocity: Vector = .zero,
        mass: Float = 1,
        isStatic: Bool = false
    ) throws {
        try shape.validate()
        guard mass.isFinite, mass > 0 else {
            throw MatterError.invalidMass
        }

        self.shape = shape
        self.position = position
        self.velocity = velocity
        self.mass = mass
        self.isStatic = isStatic
    }
}

/// Factories analogous to Matter.js's `Matter.Bodies` helpers.
@frozen
public enum Bodies {
    /// Creates a circular body definition.
    public static func circle(
        at position: Vector,
        radius: Float,
        velocity: Vector = .zero,
        mass: Float = 1,
        isStatic: Bool = false
    ) throws -> BodyDefinition {
        try BodyDefinition(
            shape: .circle(radius: radius),
            position: position,
            velocity: velocity,
            mass: mass,
            isStatic: isStatic
        )
    }

    /// Creates an axis-aligned rectangular body definition.
    public static func rectangle(
        at position: Vector,
        width: Float,
        height: Float,
        velocity: Vector = .zero,
        mass: Float = 1,
        isStatic: Bool = false
    ) throws -> BodyDefinition {
        try BodyDefinition(
            shape: .rectangle(width: width, height: height),
            position: position,
            velocity: velocity,
            mass: mass,
            isStatic: isStatic
        )
    }
}

/// A value snapshot of one body owned by a ``World``.
@frozen
public struct Body: Sendable, Hashable, Codable {
    /// The stable identity assigned by the owning world.
    public let id: BodyID
    /// The body's immutable collision geometry.
    public let shape: BodyShape
    /// The current center position in world coordinates.
    public var position: Vector
    /// The current linear velocity in world units per second.
    public var velocity: Vector
    /// The force accumulated for the next integration tick.
    public private(set) var force: Vector
    /// The finite, positive mass supplied by the body definition.
    public let mass: Float
    /// Whether this body ignores forces and integration.
    public let isStatic: Bool

    /// The reciprocal mass used by the integrators.
    ///
    /// Static bodies have no inverse mass and return zero.
    public var inverseMass: Float {
        isStatic ? 0 : 1 / mass
    }

    init(id: BodyID, definition: BodyDefinition) {
        self.id = id
        self.shape = definition.shape
        self.position = definition.position
        self.velocity = definition.velocity
        self.force = .zero
        self.mass = definition.mass
        self.isStatic = definition.isStatic
    }

    /// Accumulates a force to be consumed at the next fixed simulation tick.
    public mutating func applyForce(_ force: Vector) {
        guard !isStatic else { return }
        self.force += force
    }

    mutating func clearForce() {
        force = .zero
    }
}
