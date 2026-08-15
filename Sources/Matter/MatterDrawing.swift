/// A semantic overlay layer emitted by ``MatterDrawingAdapter``.
@frozen
public enum MatterDrawingLayer: String, CaseIterable, Sendable, Hashable, Codable {
    /// Exact circle and polygon body geometry.
    case bodies
    /// Polygon vertices emitted as individual points.
    case vertices
    /// Lines connecting resolved constraint anchors.
    case constraints
    /// Contact points and penetration-normal segments.
    case contacts
    /// Axis-aligned broad-phase bounds.
    case bounds
}

/// Selects the layers included in a renderer-neutral drawing snapshot.
@frozen
public struct MatterDrawingOptions: OptionSet, Sendable, Hashable, Codable {
    /// The serialized option bits.
    public let rawValue: UInt8

    /// Creates options from serialized option bits.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Includes exact body geometry.
    public static let bodies = Self(rawValue: 1 << 0)
    /// Includes polygon vertices.
    public static let vertices = Self(rawValue: 1 << 1)
    /// Includes resolved constraints.
    public static let constraints = Self(rawValue: 1 << 2)
    /// Includes contact points and normals.
    public static let contacts = Self(rawValue: 1 << 3)
    /// Includes body bounds.
    public static let bounds = Self(rawValue: 1 << 4)

    /// Body geometry and constraints for an ordinary presentation.
    public static let standard: Self = [.bodies, .constraints]
    /// Every available diagnostic layer.
    public static let debug: Self = [.bodies, .vertices, .constraints, .contacts, .bounds]
}

/// The stable Matter value that produced a drawing command.
@frozen
public enum MatterDrawingSource: Sendable, Hashable, Codable {
    /// Geometry, vertices, or bounds from one body.
    case body(BodyID)
    /// A segment from one resolved constraint.
    case constraint(ConstraintID)
    /// A contact point or normal from one colliding body pair.
    case collision(BodyPair)
}

/// Renderer-neutral 2D geometry suitable for P5, Core Graphics, or export.
@frozen
public enum MatterDrawingPrimitive: Sendable, Hashable, Codable {
    /// An exact circle described by its center and radius.
    case circle(center: Vector, radius: Float)
    /// A closed polygon described by ordered world-space vertices.
    case polygon(vertices: [Vector])
    /// A line between two world-space points.
    case segment(start: Vector, end: Vector)
    /// One world-space point.
    case point(Vector)
    /// One axis-aligned world-space box.
    case bounds(Bounds)
}

/// One value-semantic drawing instruction with semantic origin metadata.
@frozen
public struct MatterDrawingCommand: Sendable, Hashable, Codable {
    /// The overlay layer used to choose presentation style.
    public let layer: MatterDrawingLayer
    /// The stable simulation value that produced the command.
    public let source: MatterDrawingSource
    /// The renderer-neutral geometry to draw.
    public let primitive: MatterDrawingPrimitive

    init(
        layer: MatterDrawingLayer,
        source: MatterDrawingSource,
        primitive: MatterDrawingPrimitive
    ) {
        self.layer = layer
        self.source = source
        self.primitive = primitive
    }
}

/// Builds immutable drawing commands without importing or retaining a renderer.
@frozen
public enum MatterDrawingAdapter {
    /// Builds stable commands for selected world and contact layers.
    ///
    /// Body and constraint order follows the world snapshot. Compound-part and
    /// contact order follows their deterministic geometry and manifold order.
    ///
    /// - Parameters:
    ///   - world: The immutable simulation snapshot to inspect.
    ///   - collisions: The collision snapshot whose contacts should be drawn.
    ///   - options: The semantic layers to emit.
    /// - Returns: Commands grouped in body, vertex, constraint, contact, and
    ///   bounds layer order when those layers are selected.
    /// - Throws: ``MatterError/unknownBody(_:)`` when a decoded constraint
    ///   references a body absent from `world`.
    public static func commands(
        for world: World,
        collisions: [Collision] = [],
        options: MatterDrawingOptions = .standard
    ) throws -> [MatterDrawingCommand] {
        var commands: [MatterDrawingCommand] = []
        if options.contains(.bodies) {
            commands.append(contentsOf: bodyCommands(in: world))
        }
        if options.contains(.vertices) {
            commands.append(contentsOf: vertexCommands(in: world))
        }
        if options.contains(.constraints) {
            commands.append(contentsOf: try constraintCommands(in: world))
        }
        if options.contains(.contacts) {
            commands.append(contentsOf: contactCommands(collisions))
        }
        if options.contains(.bounds) {
            commands.append(contentsOf: boundsCommands(in: world))
        }
        return commands
    }
}

private extension MatterDrawingAdapter {
    static func bodyCommands(in world: World) -> [MatterDrawingCommand] {
        world.bodies.flatMap { body in
            body.collisionParts.map { part in
                let primitive: MatterDrawingPrimitive
                if case let .circle(radius) = part.shape {
                    primitive = .circle(center: part.position, radius: radius)
                } else {
                    primitive = .polygon(vertices: part.vertices)
                }
                return MatterDrawingCommand(
                    layer: .bodies,
                    source: .body(body.id),
                    primitive: primitive
                )
            }
        }
    }

    static func vertexCommands(in world: World) -> [MatterDrawingCommand] {
        world.bodies.flatMap { body in
            body.collisionParts.flatMap { part in
                part.vertices.map { vertex in
                    MatterDrawingCommand(
                        layer: .vertices,
                        source: .body(body.id),
                        primitive: .point(vertex)
                    )
                }
            }
        }
    }

    static func constraintCommands(in world: World) throws -> [MatterDrawingCommand] {
        let bodies = Dictionary(uniqueKeysWithValues: world.bodies.map { ($0.id, $0) })
        return try world.constraints.map { constraint in
            MatterDrawingCommand(
                layer: .constraints,
                source: .constraint(constraint.id),
                primitive: .segment(
                    start: try point(for: constraint.first, bodies: bodies),
                    end: try point(for: constraint.second, bodies: bodies)
                )
            )
        }
    }

    static func point(
        for anchor: ConstraintAnchor,
        bodies: [BodyID: Body]
    ) throws -> Vector {
        switch anchor {
        case let .fixed(point):
            return point
        case let .body(identifier, local):
            guard let body = bodies[identifier] else {
                throw MatterError.unknownBody(identifier)
            }
            return body.position + local.rotated(by: body.angle)
        }
    }

    static func contactCommands(_ collisions: [Collision]) -> [MatterDrawingCommand] {
        collisions.flatMap { collision in
            collision.contacts.flatMap { contact in
                let source = MatterDrawingSource.collision(collision.pair)
                return [
                    MatterDrawingCommand(
                        layer: .contacts,
                        source: source,
                        primitive: .point(contact.position)
                    ),
                    MatterDrawingCommand(
                        layer: .contacts,
                        source: source,
                        primitive: .segment(
                            start: contact.position,
                            end: contact.position + collision.normal * contact.penetration
                        )
                    ),
                ]
            }
        }
    }

    static func boundsCommands(in world: World) -> [MatterDrawingCommand] {
        world.bodies.map { body in
            MatterDrawingCommand(
                layer: .bounds,
                source: .body(body.id),
                primitive: .bounds(body.bounds)
            )
        }
    }
}
