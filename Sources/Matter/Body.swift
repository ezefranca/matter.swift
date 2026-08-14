/// The stable identity assigned to a body by a ``World``.
@frozen
public struct BodyID: RawRepresentable, Sendable, Hashable, Codable, Comparable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A body shape supported by the first Matter vertical slice.
@frozen
public enum BodyShape: Sendable, Hashable, Codable {
    case circle(radius: Float)
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
    public var shape: BodyShape
    public var position: Vector
    public var velocity: Vector
    public var mass: Float
    public var isStatic: Bool

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
    public let id: BodyID
    public let shape: BodyShape
    public var position: Vector
    public var velocity: Vector
    public private(set) var force: Vector
    public let mass: Float
    public let isStatic: Bool

    /// The reciprocal mass used by the integrators. Static bodies have no inverse mass.
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
