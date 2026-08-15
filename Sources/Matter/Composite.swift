import Foundation

/// The stable identity assigned to a composite by a ``World``.
@frozen
public struct CompositeID: RawRepresentable, Sendable, Hashable, Codable, Comparable {
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

/// A value snapshot that groups bodies inside a ``World`` hierarchy.
///
/// A composite owns references, not duplicate body state. A body can belong
/// directly to at most one composite, while descendant queries can include the
/// bodies assigned to every child composite.
@frozen
public struct Composite: Sendable, Hashable, Codable {
    /// The stable identity assigned by the owning world.
    public let id: CompositeID

    /// A nonempty human-readable name.
    public let label: String

    /// String metadata reserved for clients and plugins.
    public let metadata: [String: String]

    /// The parent composite, or `nil` when this is a root composite.
    public private(set) var parent: CompositeID?

    /// Bodies assigned directly to this composite in stable assignment order.
    public private(set) var bodyIDs: [BodyID]

    init(
        id: CompositeID,
        label: String,
        metadata: [String: String],
        parent: CompositeID?
    ) {
        self.id = id
        self.label = label
        self.metadata = metadata
        self.parent = parent
        self.bodyIDs = []
    }

    mutating func append(_ body: BodyID) {
        bodyIDs.append(body)
    }

    mutating func remove(_ body: BodyID) {
        bodyIDs.removeAll { $0 == body }
    }

    mutating func remove(_ bodies: Set<BodyID>) {
        bodyIDs.removeAll { bodies.contains($0) }
    }

    mutating func removeAllBodies() {
        bodyIDs.removeAll(keepingCapacity: true)
    }

    mutating func reparent(to parent: CompositeID?) {
        self.parent = parent
    }

    static func validate(label: String, metadata: [String: String]) throws {
        guard !label.isEmpty, label == label.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw MatterError.invalidLabel
        }
        guard
            metadata.keys.allSatisfy({ !$0.isEmpty }),
            metadata.values.allSatisfy({ $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        else {
            throw MatterError.invalidMetadata
        }
    }
}
