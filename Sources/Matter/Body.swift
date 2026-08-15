/// A value snapshot of one body owned by a ``World``.
@frozen
public struct Body: Sendable, Hashable, Codable {
    /// The stable identity assigned by the owning world.
    public let id: BodyID

    /// The body's immutable collision geometry.
    public let shape: BodyShape

    /// The current center position in world coordinates.
    public private(set) var position: Vector

    /// The current center of mass in world coordinates.
    ///
    /// Bodies use their local origin as center of mass. Compound callers should
    /// arrange part geometry around that origin.
    public var centerOfMass: Vector {
        position
    }

    /// The current clockwise rotation in radians.
    public private(set) var angle: Float

    /// The current linear velocity in world units per second.
    public private(set) var velocity: Vector

    /// The current clockwise angular velocity in radians per second.
    public private(set) var angularVelocity: Float

    /// The force accumulated for the next integration tick.
    public private(set) var force: Vector

    /// The torque accumulated for the next integration tick.
    public private(set) var torque: Float

    /// The finite, positive mass supplied by the body definition.
    public let mass: Float

    /// The local-space area of the collision shape.
    public let area: Float

    /// Mass divided by shape area.
    public let density: Float

    /// The scalar moment of inertia around the body origin.
    public let inertia: Float

    /// Whether this body ignores forces and integration.
    public let isStatic: Bool

    /// Whether collisions generate events without physical impulses.
    public let isSensor: Bool

    /// A human-readable body label.
    public let label: String

    /// String metadata reserved for clients and plugins.
    public let metadata: [String: String]

    /// Restitution, friction, drag, and penetration tolerance.
    public let material: BodyMaterial

    /// Normal impulse energy retained after collision.
    public var restitution: Float {
        material.restitution
    }

    /// Dynamic Coulomb friction coefficient.
    public var friction: Float {
        material.friction
    }

    /// Static Coulomb friction coefficient.
    public var staticFriction: Float {
        material.staticFriction
    }

    /// Linear and angular drag per second.
    public var airFriction: Float {
        material.airFriction
    }

    /// Positional penetration tolerance.
    public var slop: Float {
        material.slop
    }

    /// Broad- and narrow-phase collision filtering.
    public let collisionFilter: CollisionFilter

    /// The reciprocal mass used by the integrators.
    ///
    /// Static bodies have no inverse mass and return zero.
    public var inverseMass: Float {
        isStatic ? 0 : 1 / mass
    }

    /// The reciprocal inertia used by angular integration.
    ///
    /// Static bodies have no inverse inertia and return zero.
    public var inverseInertia: Float {
        isStatic ? 0 : 1 / inertia
    }

    /// Polygon vertices transformed into world coordinates.
    ///
    /// Circles return an empty array. Compound bodies flatten polygonal part
    /// vertices in part order and omit exact circular boundaries.
    public var vertices: [Vector] {
        switch shape {
        case .compound:
            collisionParts.flatMap(\.vertices)
        default:
            shape.localVertices.map { $0.rotated(by: angle) + position }
        }
    }

    /// The current axis-aligned broad-phase bounds.
    public var bounds: Bounds {
        switch shape {
        case let .circle(radius):
            return Bounds(
                minimum: position - Vector(x: radius, y: radius),
                maximum: position + Vector(x: radius, y: radius)
            )
        case .compound:
            let partBounds = collisionParts.map(\.bounds)
            var minimum = partBounds[0].minimum
            var maximum = partBounds[0].maximum
            for bounds in partBounds.dropFirst() {
                minimum.x = min(minimum.x, bounds.minimum.x)
                minimum.y = min(minimum.y, bounds.minimum.y)
                maximum.x = max(maximum.x, bounds.maximum.x)
                maximum.y = max(maximum.y, bounds.maximum.y)
            }
            return Bounds(
                minimum: minimum,
                maximum: maximum
            )
        default:
            return Bounds(containing: vertices)
        }
    }

    var collisionParts: [Body] {
        guard case let .compound(parts) = shape else { return [self] }
        return parts.map { part in
            Body(
                partOf: self,
                shape: part.shape,
                position: position + part.position.rotated(by: angle),
                angle: angle + part.angle
            )
        }
    }

    init(id: BodyID, definition: BodyDefinition) {
        self.id = id
        self.shape = definition.shape
        self.position = definition.position
        self.angle = definition.angle
        self.velocity = definition.velocity
        self.angularVelocity = definition.angularVelocity
        self.force = .zero
        self.torque = 0
        self.mass = definition.mass
        self.area = definition.shape.area
        self.density = definition.mass / definition.shape.area
        self.inertia = definition.shape.inertia(forMass: definition.mass)
        self.isStatic = definition.isStatic
        self.isSensor = definition.isSensor
        self.label = definition.label
        self.metadata = definition.metadata
        self.material = definition.material
        self.collisionFilter = definition.collisionFilter
    }

    private init(partOf parent: Body, shape: BodyShape, position: Vector, angle: Float) {
        self.id = parent.id
        self.shape = shape
        self.position = position
        self.angle = angle
        self.velocity = parent.velocity
        self.angularVelocity = parent.angularVelocity
        self.force = parent.force
        self.torque = parent.torque
        self.mass = parent.mass
        self.area = shape.area
        self.density = parent.density
        self.inertia = parent.inertia
        self.isStatic = parent.isStatic
        self.isSensor = parent.isSensor
        self.label = parent.label
        self.metadata = parent.metadata
        self.material = parent.material
        self.collisionFilter = parent.collisionFilter
    }

    /// Accumulates a force to be consumed at the next fixed simulation tick.
    public mutating func applyForce(_ force: Vector) {
        guard !isStatic else { return }
        precondition(force.isFinite)
        self.force += force
    }

    /// Accumulates force and its moment around the center of mass.
    public mutating func applyForce(_ force: Vector, at point: Vector) {
        guard !isStatic else { return }
        precondition(force.isFinite && point.isFinite)
        self.force += force
        torque += (point - position).cross(force)
    }

    /// Accumulates torque for the next fixed simulation tick.
    public mutating func applyTorque(_ torque: Float) {
        guard !isStatic else { return }
        precondition(torque.isFinite)
        self.torque += torque
    }

    /// Repositions the body without changing its velocity.
    public mutating func setPosition(_ position: Vector) throws {
        guard position.isFinite else { throw MatterError.invalidVector }
        self.position = position
    }

    /// Translates the body without changing its velocity.
    public mutating func translate(by offset: Vector) throws {
        try setPosition(position + offset)
    }

    /// Sets the clockwise body angle without changing angular velocity.
    public mutating func setAngle(_ angle: Float) throws {
        guard angle.isFinite else { throw MatterError.invalidAngle }
        self.angle = angle
    }

    /// Rotates the body clockwise around its own center.
    public mutating func rotate(by angle: Float) throws {
        try setAngle(self.angle + angle)
    }

    /// Replaces the body's linear velocity.
    public mutating func setVelocity(_ velocity: Vector) throws {
        guard velocity.isFinite else { throw MatterError.invalidVector }
        self.velocity = velocity
    }

    /// Replaces the body's clockwise angular velocity.
    public mutating func setAngularVelocity(_ angularVelocity: Float) throws {
        guard angularVelocity.isFinite else { throw MatterError.invalidAngle }
        self.angularVelocity = angularVelocity
    }

    mutating func clearForces() {
        force = .zero
        torque = 0
    }

    mutating func replaceKinematics(
        position: Vector,
        angle: Float,
        velocity: Vector,
        angularVelocity: Float
    ) {
        self.position = position
        self.angle = angle
        self.velocity = velocity
        self.angularVelocity = angularVelocity
        clearForces()
    }

    mutating func applyImpulse(_ impulse: Vector, at point: Vector) {
        guard !isStatic else { return }
        velocity += impulse * inverseMass
        angularVelocity += (point - position).cross(impulse) * inverseInertia
    }

    mutating func applyPositionCorrection(_ correction: Vector) {
        guard !isStatic else { return }
        position += correction
    }

    mutating func applyPositionImpulse(_ impulse: Vector, at point: Vector) {
        guard !isStatic else { return }
        let radius = point - position
        position += impulse * inverseMass
        angle += radius.cross(impulse) * inverseInertia
    }

    mutating func applyAngularPositionImpulse(_ impulse: Float) {
        guard !isStatic else { return }
        angle += impulse * inverseInertia
    }

    mutating func applyAngularImpulse(_ impulse: Float) {
        guard !isStatic else { return }
        angularVelocity += impulse * inverseInertia
    }

    mutating func integrate(gravity: Vector, timeStep: Float) {
        guard !isStatic else {
            clearForces()
            return
        }
        let damping = max(0, 1 - material.airFriction * timeStep)
        velocity = (velocity + (gravity + force * inverseMass) * timeStep) * damping
        angularVelocity = (angularVelocity + torque * inverseInertia * timeStep) * damping
        position += velocity * timeStep
        angle += angularVelocity * timeStep
        clearForces()
    }
}
