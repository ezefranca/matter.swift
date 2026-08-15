import Foundation

/// The location and mass that generate an ``Attractor`` field.
@frozen
public enum AttractionSource: Sendable, Hashable, Codable {
    /// A fixed world-space point with a finite positive mass.
    case point(position: Vector, mass: Float)

    /// A body's current center and mass, resolved from the world on every use.
    case body(BodyID)
}

/// One deterministic force accumulated for a body by an ``Attractor``.
@frozen
public struct ForceApplication: Sendable, Hashable, Codable {
    /// The body that receives the force.
    public let body: BodyID

    /// The force vector accumulated for the next simulation tick.
    public let force: Vector

    init(body: BodyID, force: Vector) {
        self.body = body
        self.force = force
    }
}

/// An inverse-square point or body force field for attraction and repulsion.
///
/// Positive strength attracts targets and negative strength repels them. The
/// source itself never receives a reciprocal force; create a second attractor
/// when a simulation needs mutual attraction.
@frozen
public struct Attractor: Sendable, Hashable, Codable {
    /// The fixed point or world body producing the field.
    public var source: AttractionSource

    /// Signed multiplier analogous to a gravitational constant.
    public var strength: Float

    /// The smallest distance used by the inverse-square calculation.
    public var minimumDistance: Float

    /// The largest distance used by the inverse-square calculation.
    public var maximumDistance: Float

    /// Optional upper bound on absolute force magnitude.
    public var maximumForce: Float?

    /// Which body collision categories may receive force.
    public var targetFilter: CollisionFilter

    /// Creates a validated inverse-square force field.
    ///
    /// Distance limits must be finite and positive, with the maximum no smaller
    /// than the minimum. Strength may be any finite signed value, including zero.
    ///
    /// - Throws: ``MatterError/invalidForceBehavior`` or
    ///   ``MatterError/invalidCollisionFilter`` for invalid configuration.
    public init(
        source: AttractionSource,
        strength: Float = 1,
        minimumDistance: Float = 5,
        maximumDistance: Float = 25,
        maximumForce: Float? = nil,
        targetFilter: CollisionFilter = .all
    ) throws {
        self.source = source
        self.strength = strength
        self.minimumDistance = minimumDistance
        self.maximumDistance = maximumDistance
        self.maximumForce = maximumForce
        self.targetFilter = targetFilter
        try validate()
    }

    /// Calculates the force for one body without mutating the world.
    ///
    /// Static, filtered, coincident, and source bodies return ``Vector/zero``.
    /// A body-backed source must exist in `world`.
    public func force(on body: Body, in world: World) throws -> Vector {
        let resolvedSource = try resolveSource(in: world)
        return force(on: body, source: resolvedSource)
    }

    /// Produces stable force applications without mutating the world.
    ///
    /// Omitting `targets` evaluates bodies in world insertion order. Explicit
    /// identifiers preserve their caller-supplied order and must be unique.
    public func applications(
        to targets: [BodyID]? = nil,
        in world: World
    ) throws -> [ForceApplication] {
        try validate()
        let source = try resolveSource(in: world)
        let bodies = try targetBodies(targets, in: world)
        return bodies.compactMap { body in
            let force = force(on: body, source: source)
            return force == .zero ? nil : ForceApplication(body: body.id, force: force)
        }
    }

    /// Accumulates this field's forces for the world's next simulation tick.
    ///
    /// Validation and lookup complete before mutation, so a thrown error leaves
    /// the world unchanged.
    @discardableResult
    public func apply(
        to targets: [BodyID]? = nil,
        in world: inout World
    ) throws -> [ForceApplication] {
        let applications = try applications(to: targets, in: world)
        for application in applications {
            try world.applyForce(application.force, to: application.body)
        }
        return applications
    }
}

private extension Attractor {
    struct ResolvedSource {
        let bodyID: BodyID?
        let position: Vector
        let mass: Float
    }

    func validate() throws {
        switch source {
        case let .point(position, mass):
            guard position.isFinite, mass.isFinite, mass > 0 else {
                throw MatterError.invalidForceBehavior
            }
        case .body:
            break
        }
        guard
            strength.isFinite,
            minimumDistance.isFinite,
            maximumDistance.isFinite,
            minimumDistance > 0,
            maximumDistance >= minimumDistance,
            maximumForce.map({ $0.isFinite && $0 > 0 }) ?? true
        else {
            throw MatterError.invalidForceBehavior
        }
        try targetFilter.validate()
    }

    func resolveSource(in world: World) throws -> ResolvedSource {
        switch source {
        case let .point(position, mass):
            return ResolvedSource(bodyID: nil, position: position, mass: mass)
        case let .body(identifier):
            guard let body = world.body(withID: identifier) else {
                throw MatterError.unknownBody(identifier)
            }
            return ResolvedSource(bodyID: identifier, position: body.position, mass: body.mass)
        }
    }

    func targetBodies(_ targets: [BodyID]?, in world: World) throws -> [Body] {
        guard let targets else { return world.bodies }
        var seen: Set<BodyID> = []
        return try targets.map { identifier in
            guard seen.insert(identifier).inserted else {
                throw MatterError.duplicateBody(identifier)
            }
            guard let body = world.body(withID: identifier) else {
                throw MatterError.unknownBody(identifier)
            }
            return body
        }
    }

    func force(on body: Body, source: ResolvedSource) -> Vector {
        guard
            !body.isStatic,
            body.id != source.bodyID,
            targetFilter.allowsCollision(with: body.collisionFilter)
        else {
            return .zero
        }
        let offset = source.position - body.position
        let distance = offset.length
        guard distance > 0 else { return .zero }
        let boundedDistance = min(max(distance, minimumDistance), maximumDistance)
        var magnitude = strength * source.mass * body.mass / (boundedDistance * boundedDistance)
        if let maximumForce, abs(magnitude) > maximumForce {
            magnitude = magnitude.sign == .minus ? -maximumForce : maximumForce
        }
        return offset / distance * magnitude
    }
}
