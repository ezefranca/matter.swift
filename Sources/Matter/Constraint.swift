import Foundation

/// The stable identity assigned to a constraint by a ``World``.
@frozen
public struct ConstraintID: RawRepresentable, Sendable, Hashable, Codable, Comparable {
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

/// One endpoint of a distance constraint.
@frozen
public enum ConstraintAnchor: Sendable, Hashable, Codable {
    /// A position fixed in world coordinates.
    case fixed(Vector)

    /// A point expressed in a body's local coordinates.
    case body(BodyID, local: Vector = .zero)

    var bodyID: BodyID? {
        guard case let .body(identifier, _) = self else { return nil }
        return identifier
    }

    func validate() throws {
        let vector: Vector
        switch self {
        case let .fixed(point):
            vector = point
        case let .body(_, local):
            vector = local
        }
        guard vector.isFinite else { throw MatterError.invalidVector }
    }
}

/// Validated input for adding a distance constraint to a ``World``.
@frozen
public struct ConstraintDefinition: Sendable, Hashable, Codable {
    /// The first fixed or body-local anchor.
    public var first: ConstraintAnchor

    /// The second fixed or body-local anchor.
    public var second: ConstraintAnchor

    /// The target distance, or `nil` to capture the initial anchor distance.
    public var length: Float?

    /// Positional correction strength per solver pass, in `0...1`.
    public var stiffness: Float

    /// Relative velocity removed per solver pass, in `0...1`.
    public var damping: Float

    /// Relative body rotation corrected per solver pass, in `0...1`.
    public var angularStiffness: Float

    /// Optional maximum corrective impulse before the constraint breaks.
    public var maximumImpulse: Float?

    /// A nonempty human-readable name.
    public var label: String

    /// String metadata reserved for clients and plugins.
    public var metadata: [String: String]

    /// Creates a validated distance-constraint definition.
    ///
    /// At least one anchor must reference a body. A world validates referenced
    /// identifiers when the definition is added.
    public init(
        first: ConstraintAnchor,
        second: ConstraintAnchor,
        length: Float? = nil,
        stiffness: Float = 1,
        damping: Float = 0,
        angularStiffness: Float = 0,
        maximumImpulse: Float? = nil,
        label: String = "Constraint",
        metadata: [String: String] = [:]
    ) throws {
        self.first = first
        self.second = second
        self.length = length
        self.stiffness = stiffness
        self.damping = damping
        self.angularStiffness = angularStiffness
        self.maximumImpulse = maximumImpulse
        self.label = label
        self.metadata = metadata
        try validate()
    }

    func validate() throws {
        try first.validate()
        try second.validate()
        guard first.bodyID != nil || second.bodyID != nil else {
            throw MatterError.invalidConstraint
        }
        guard first.bodyID == nil || first.bodyID != second.bodyID else {
            throw MatterError.invalidConstraint
        }
        guard
            length.map({ $0.isFinite && $0 >= 0 }) ?? true,
            stiffness.isFinite,
            damping.isFinite,
            angularStiffness.isFinite,
            (0...1).contains(stiffness),
            (0...1).contains(damping),
            (0...1).contains(angularStiffness),
            maximumImpulse.map({ $0.isFinite && $0 > 0 }) ?? true
        else {
            throw MatterError.invalidConstraint
        }
        try Composite.validate(label: label, metadata: metadata)
    }
}

/// A value snapshot of one distance constraint owned by a ``World``.
@frozen
public struct Constraint: Sendable, Hashable, Codable {
    /// The stable identity assigned by the owning world.
    public let id: ConstraintID

    /// The first fixed or body-local anchor.
    public let first: ConstraintAnchor

    /// The second fixed or body-local anchor.
    public let second: ConstraintAnchor

    /// The finite, nonnegative target anchor distance.
    public let length: Float

    /// Positional correction strength per solver pass, in `0...1`.
    public let stiffness: Float

    /// Relative velocity removed per solver pass, in `0...1`.
    public let damping: Float

    /// Relative body rotation corrected per solver pass, in `0...1`.
    public let angularStiffness: Float

    /// Optional maximum corrective impulse before automatic removal.
    public let maximumImpulse: Float?

    /// The relative body angle captured when the constraint was added.
    public let referenceAngle: Float

    /// A nonempty human-readable name.
    public let label: String

    /// String metadata reserved for clients and plugins.
    public let metadata: [String: String]

    init(
        id: ConstraintID,
        definition: ConstraintDefinition,
        length: Float,
        referenceAngle: Float
    ) {
        self.id = id
        self.first = definition.first
        self.second = definition.second
        self.length = length
        self.stiffness = definition.stiffness
        self.damping = definition.damping
        self.angularStiffness = definition.angularStiffness
        self.maximumImpulse = definition.maximumImpulse
        self.referenceAngle = referenceAngle
        self.label = definition.label
        self.metadata = definition.metadata
    }

    /// Whether either endpoint references a body identifier.
    public func references(_ body: BodyID) -> Bool {
        first.bodyID == body || second.bodyID == body
    }
}

/// Factories for common point-to-body and body-to-body constraints.
@frozen
public enum Constraints {
    /// Creates a point-to-body distance constraint.
    public static func pin(
        _ body: BodyID,
        localAnchor: Vector = .zero,
        to point: Vector,
        length: Float? = nil,
        stiffness: Float = 1,
        damping: Float = 0,
        angularStiffness: Float = 0,
        maximumImpulse: Float? = nil
    ) throws -> ConstraintDefinition {
        try ConstraintDefinition(
            first: .fixed(point),
            second: .body(body, local: localAnchor),
            length: length,
            stiffness: stiffness,
            damping: damping,
            angularStiffness: angularStiffness,
            maximumImpulse: maximumImpulse,
            label: "Pin"
        )
    }

    /// Creates a body-to-body distance constraint.
    public static func distance(
        between first: BodyID,
        localAnchor firstAnchor: Vector = .zero,
        and second: BodyID,
        localAnchor secondAnchor: Vector = .zero,
        length: Float? = nil,
        stiffness: Float = 1,
        damping: Float = 0,
        angularStiffness: Float = 0,
        maximumImpulse: Float? = nil
    ) throws -> ConstraintDefinition {
        try ConstraintDefinition(
            first: .body(first, local: firstAnchor),
            second: .body(second, local: secondAnchor),
            length: length,
            stiffness: stiffness,
            damping: damping,
            angularStiffness: angularStiffness,
            maximumImpulse: maximumImpulse,
            label: "Distance"
        )
    }

    /// Creates a compliant, damped body-to-body spring.
    public static func spring(
        between first: BodyID,
        and second: BodyID,
        length: Float? = nil,
        stiffness: Float = 0.2,
        damping: Float = 0.1,
        maximumImpulse: Float? = nil
    ) throws -> ConstraintDefinition {
        try distance(
            between: first,
            and: second,
            length: length,
            stiffness: stiffness,
            damping: damping,
            maximumImpulse: maximumImpulse
        )
    }

    /// Creates adjacent distance constraints for an ordered body chain.
    public static func chain(
        _ bodies: [BodyID],
        length: Float? = nil,
        stiffness: Float = 1,
        damping: Float = 0,
        angularStiffness: Float = 0,
        maximumImpulse: Float? = nil
    ) throws -> [ConstraintDefinition] {
        guard bodies.count >= 2 else { throw MatterError.invalidConstraint }
        return try zip(bodies, bodies.dropFirst()).map { first, second in
            var definition = try distance(
                between: first,
                and: second,
                length: length,
                stiffness: stiffness,
                damping: damping,
                angularStiffness: angularStiffness,
                maximumImpulse: maximumImpulse
            )
            definition.label = "Chain"
            return definition
        }
    }

    /// Creates a pin configured as a pendulum arm.
    public static func pendulum(
        _ body: BodyID,
        pivot: Vector,
        localAnchor: Vector = .zero,
        length: Float? = nil,
        stiffness: Float = 1,
        damping: Float = 0.05,
        maximumImpulse: Float? = nil
    ) throws -> ConstraintDefinition {
        var definition = try pin(
            body,
            localAnchor: localAnchor,
            to: pivot,
            length: length,
            stiffness: stiffness,
            damping: damping,
            maximumImpulse: maximumImpulse
        )
        definition.label = "Pendulum"
        return definition
    }

    /// Creates a chain whose first and last bodies are pinned to bridge anchors.
    public static func bridge(
        _ bodies: [BodyID],
        from start: Vector,
        to end: Vector,
        segmentLength: Float? = nil,
        stiffness: Float = 0.9,
        damping: Float = 0.1,
        maximumImpulse: Float? = nil
    ) throws -> [ConstraintDefinition] {
        var definitions = try chain(
            bodies,
            length: segmentLength,
            stiffness: stiffness,
            damping: damping,
            maximumImpulse: maximumImpulse
        )
        var firstPin = try pin(
            bodies[0],
            to: start,
            length: segmentLength,
            stiffness: stiffness,
            damping: damping,
            maximumImpulse: maximumImpulse
        )
        firstPin.label = "Bridge Anchor"
        var lastPin = try pin(
            bodies[bodies.count - 1],
            to: end,
            length: segmentLength,
            stiffness: stiffness,
            damping: damping,
            maximumImpulse: maximumImpulse
        )
        lastPin.label = "Bridge Anchor"
        definitions.append(firstPin)
        definitions.append(lastPin)
        return definitions
    }

    /// Creates horizontal, vertical, and optional diagonal constraints for a grid.
    public static func mesh(
        _ rows: [[BodyID]],
        length: Float? = nil,
        stiffness: Float = 0.8,
        damping: Float = 0.1,
        crossBrace: Bool = true,
        maximumImpulse: Float? = nil
    ) throws -> [ConstraintDefinition] {
        let columnCount = try validatedColumnCount(in: rows)
        var definitions: [ConstraintDefinition] = []
        for row in rows {
            if row.count > 1 {
                definitions.append(
                    contentsOf: try chain(
                        row,
                        length: length,
                        stiffness: stiffness,
                        damping: damping,
                        maximumImpulse: maximumImpulse
                    )
                )
            }
        }
        if rows.count > 1 {
            for rowIndex in 0..<(rows.count - 1) {
                for columnIndex in 0..<columnCount {
                    definitions.append(
                        try distance(
                            between: rows[rowIndex][columnIndex],
                            and: rows[rowIndex + 1][columnIndex],
                            length: length,
                            stiffness: stiffness,
                            damping: damping,
                            maximumImpulse: maximumImpulse
                        )
                    )
                    if crossBrace, columnIndex + 1 < columnCount {
                        definitions.append(
                            try distance(
                                between: rows[rowIndex][columnIndex],
                                and: rows[rowIndex + 1][columnIndex + 1],
                                length: length,
                                stiffness: stiffness,
                                damping: damping,
                                maximumImpulse: maximumImpulse
                            )
                        )
                        definitions.append(
                            try distance(
                                between: rows[rowIndex][columnIndex + 1],
                                and: rows[rowIndex + 1][columnIndex],
                                length: length,
                                stiffness: stiffness,
                                damping: damping,
                                maximumImpulse: maximumImpulse
                            )
                        )
                    }
                }
            }
        }
        for index in definitions.indices {
            definitions[index].label = "Mesh"
        }
        return definitions
    }

    /// Creates a cross-braced mesh configured for a compliant soft body.
    public static func softBody(
        _ rows: [[BodyID]],
        length: Float? = nil,
        stiffness: Float = 0.5,
        damping: Float = 0.15,
        maximumImpulse: Float? = nil
    ) throws -> [ConstraintDefinition] {
        var definitions = try mesh(
            rows,
            length: length,
            stiffness: stiffness,
            damping: damping,
            crossBrace: true,
            maximumImpulse: maximumImpulse
        )
        for index in definitions.indices {
            definitions[index].label = "Soft Body"
        }
        return definitions
    }

    private static func validatedColumnCount(in rows: [[BodyID]]) throws -> Int {
        guard let columnCount = rows.first?.count, columnCount > 0 else {
            throw MatterError.invalidConstraint
        }
        guard rows.allSatisfy({ $0.count == columnCount }) else {
            throw MatterError.invalidConstraint
        }
        return columnCount
    }
}
