import Foundation

/// Surface and damping properties used by collision resolution and integration.
@frozen
public struct BodyMaterial: Sendable, Hashable, Codable {
    /// Normal impulse energy retained after collision, in `0...1`.
    public var restitution: Float

    /// Dynamic Coulomb friction coefficient, greater than or equal to zero.
    public var friction: Float

    /// Static Coulomb friction coefficient, greater than or equal to zero.
    public var staticFriction: Float

    /// Linear and angular drag per second, greater than or equal to zero.
    public var airFriction: Float

    /// Positional penetration tolerance, greater than or equal to zero.
    public var slop: Float

    /// Creates material properties that a ``BodyDefinition`` validates on use.
    public init(
        restitution: Float = 0,
        friction: Float = 0.1,
        staticFriction: Float = 0.5,
        airFriction: Float = 0,
        slop: Float = 0.05
    ) {
        self.restitution = restitution
        self.friction = friction
        self.staticFriction = staticFriction
        self.airFriction = airFriction
        self.slop = slop
    }

    /// Matter's standard material defaults.
    public static let standard = Self()

    func validate() throws {
        guard
            restitution.isFinite,
            friction.isFinite,
            staticFriction.isFinite,
            airFriction.isFinite,
            slop.isFinite,
            (0...1).contains(restitution),
            friction >= 0,
            staticFriction >= 0,
            airFriction >= 0,
            slop >= 0
        else {
            throw MatterError.invalidMaterial
        }
    }
}

/// Collision filtering shared by broad-phase and narrow-phase queries.
@frozen
public struct CollisionFilter: Sendable, Hashable, Codable {
    /// A signed group override.
    ///
    /// Equal positive groups always collide; equal negative groups never collide.
    public var group: Int32

    /// The body's nonzero collision category bit field.
    public var category: UInt32

    /// The categories this body accepts.
    public var mask: UInt32

    /// Creates a collision filter that a ``BodyDefinition`` validates on use.
    public init(group: Int32 = 0, category: UInt32 = 1, mask: UInt32 = .max) {
        self.group = group
        self.category = category
        self.mask = mask
    }

    /// A filter that participates in the default category and accepts all categories.
    public static let all = Self()

    /// Returns whether two filters allow collision tests.
    public func allowsCollision(with other: Self) -> Bool {
        if group != 0, group == other.group {
            return group > 0
        }
        return (mask & other.category) != 0 && (other.mask & category) != 0
    }

    func validate() throws {
        guard category != 0 else {
            throw MatterError.invalidCollisionFilter
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

    /// The initial clockwise rotation in radians.
    public var angle: Float

    /// The initial linear velocity in world units per second.
    public var velocity: Vector

    /// The initial clockwise angular velocity in radians per second.
    public var angularVelocity: Float

    /// The finite mass greater than zero; static bodies retain it for serialization.
    public var mass: Float

    /// Whether integration ignores forces and leaves the body fixed.
    public var isStatic: Bool

    /// Whether a dynamic body begins asleep and excluded from integration.
    public var isSleeping: Bool

    /// Whether collisions generate events without physical impulses.
    public var isSensor: Bool

    /// A nonempty human-readable body label.
    public var label: String

    /// String metadata reserved for clients and plugins.
    public var metadata: [String: String]

    /// Restitution, friction, drag, and penetration tolerance.
    public var material: BodyMaterial

    /// Broad- and narrow-phase collision filtering.
    public var collisionFilter: CollisionFilter

    /// Creates a validated definition for insertion into a world.
    ///
    /// - Throws: A ``MatterError`` when geometry, motion, mass, material,
    ///   filtering, label, or metadata is invalid.
    public init(
        shape: BodyShape,
        position: Vector,
        angle: Float = 0,
        velocity: Vector = .zero,
        angularVelocity: Float = 0,
        mass: Float = 1,
        isStatic: Bool = false,
        isSleeping: Bool = false,
        isSensor: Bool = false,
        label: String = "Body",
        metadata: [String: String] = [:],
        material: BodyMaterial = .standard,
        collisionFilter: CollisionFilter = .all
    ) throws {
        self.shape = shape
        self.position = position
        self.angle = angle
        self.velocity = velocity
        self.angularVelocity = angularVelocity
        self.mass = mass
        self.isStatic = isStatic
        self.isSleeping = isSleeping
        self.isSensor = isSensor
        self.label = label
        self.metadata = metadata
        self.material = material
        self.collisionFilter = collisionFilter
        try validate()
    }

    func validate() throws {
        try shape.validate()
        guard mass.isFinite, mass > 0 else {
            throw MatterError.invalidMass
        }
        guard position.isFinite, velocity.isFinite else {
            throw MatterError.invalidVector
        }
        guard angle.isFinite, angularVelocity.isFinite else {
            throw MatterError.invalidAngle
        }
        guard !label.isEmpty, label == label.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw MatterError.invalidLabel
        }
        guard
            metadata.keys.allSatisfy({ !$0.isEmpty }),
            metadata.values.allSatisfy({ $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        else {
            throw MatterError.invalidMetadata
        }
        try material.validate()
        try collisionFilter.validate()
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
            isStatic: isStatic,
            label: "Circle"
        )
    }

    /// Creates a rectangular body definition.
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
            isStatic: isStatic,
            label: "Rectangle"
        )
    }

    /// Creates a regular convex polygon definition.
    public static func polygon(
        at position: Vector,
        radius: Float,
        sides: Int,
        angle: Float = 0,
        mass: Float = 1,
        isStatic: Bool = false
    ) throws -> BodyDefinition {
        guard radius.isFinite, radius > 0, sides >= 3 else {
            throw MatterError.invalidShapeDimension
        }
        let step = (2 * Float.pi) / Float(sides)
        let vertices = (0..<sides).map { index in
            Vector(
                x: Foundation.cos(Float(index) * step) * radius,
                y: Foundation.sin(Float(index) * step) * radius
            )
        }
        return try BodyDefinition(
            shape: .polygon(vertices: vertices),
            position: position,
            angle: angle,
            mass: mass,
            isStatic: isStatic,
            label: "Polygon"
        )
    }

    /// Creates an isosceles trapezoid definition.
    public static func trapezoid(
        at position: Vector,
        width: Float,
        height: Float,
        slope: Float,
        angle: Float = 0,
        mass: Float = 1,
        isStatic: Bool = false
    ) throws -> BodyDefinition {
        try BodyDefinition(
            shape: .trapezoid(width: width, height: height, slope: slope),
            position: position,
            angle: angle,
            mass: mass,
            isStatic: isStatic,
            label: "Trapezoid"
        )
    }

    /// Creates a body from validated convex local vertices.
    public static func vertices(
        at position: Vector,
        vertices: [Vector],
        angle: Float = 0,
        mass: Float = 1,
        isStatic: Bool = false
    ) throws -> BodyDefinition {
        try BodyDefinition(
            shape: .polygon(vertices: vertices),
            position: position,
            angle: angle,
            mass: mass,
            isStatic: isStatic,
            label: "Polygon"
        )
    }

    /// Creates one rigid body from two or more transformed convex parts.
    public static func compound(
        at position: Vector,
        parts: [CompoundPart],
        angle: Float = 0,
        mass: Float = 1,
        isStatic: Bool = false
    ) throws -> BodyDefinition {
        try BodyDefinition(
            shape: .compound(parts: parts),
            position: position,
            angle: angle,
            mass: mass,
            isStatic: isStatic,
            label: "Compound"
        )
    }

    /// Creates a convex or decomposed concave body from simple local vertices.
    ///
    /// Convex input retains one polygon shape. Concave input uses
    /// ``ConcaveDecomposer`` and stores its triangles as one compound body.
    public static func fromVertices(
        at position: Vector,
        vertices: [Vector],
        angle: Float = 0,
        mass: Float = 1,
        isStatic: Bool = false
    ) throws -> BodyDefinition {
        let parts = try ConcaveDecomposer.decompose(vertices)
        let shape = parts.count == 1 ? parts[0].shape : BodyShape.compound(parts: parts)
        return try BodyDefinition(
            shape: shape,
            position: position,
            angle: angle,
            mass: mass,
            isStatic: isStatic,
            label: parts.count == 1 ? "Polygon" : "Concave Compound"
        )
    }
}
