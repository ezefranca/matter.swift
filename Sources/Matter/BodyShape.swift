import Foundation

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

/// Collision geometry expressed in body-local coordinates.
@frozen
public enum BodyShape: Sendable, Hashable, Codable {
    /// A circle with a finite radius greater than zero.
    case circle(radius: Float)

    /// A rectangle with finite width and height greater than zero.
    case rectangle(width: Float, height: Float)

    /// A convex polygon containing at least three finite local vertices.
    case polygon(vertices: [Vector])

    /// An isosceles trapezoid whose slope is in `0..<1`.
    case trapezoid(width: Float, height: Float, slope: Float)

    /// The local-space area enclosed by this shape.
    public var area: Float {
        switch self {
        case let .circle(radius):
            .pi * radius * radius
        case let .rectangle(width, height):
            width * height
        case let .polygon(vertices):
            abs(Self.signedDoubleArea(of: vertices)) / 2
        case let .trapezoid(width, height, slope):
            width * height * (1 - slope / 2)
        }
    }

    /// Vertices for polygonal shapes in body-local coordinates.
    ///
    /// Circles return an empty array because their exact curved boundary is not
    /// represented by an arbitrary tessellation.
    public var localVertices: [Vector] {
        switch self {
        case .circle:
            []
        case let .rectangle(width, height):
            Self.rectangleVertices(width: width, height: height)
        case let .polygon(vertices):
            vertices
        case let .trapezoid(width, height, slope):
            Self.trapezoidVertices(width: width, height: height, slope: slope)
        }
    }

    /// Returns the scalar moment of inertia around the body's local origin.
    ///
    /// - Parameter mass: A finite positive mass.
    /// - Returns: The shape's scalar moment of inertia.
    public func inertia(forMass mass: Float) -> Float {
        precondition(mass.isFinite && mass > 0)
        switch self {
        case let .circle(radius):
            return mass * radius * radius / 2
        case let .rectangle(width, height):
            return mass * ((width * width) + (height * height)) / 12
        case .polygon, .trapezoid:
            let vertices = localVertices
            var numerator: Float = 0
            var denominator: Float = 0
            for index in vertices.indices {
                let first = vertices[index]
                let second = vertices[(index + 1) % vertices.count]
                let cross = first.cross(second)
                numerator +=
                    cross
                    * (first.dot(first) + first.dot(second) + second.dot(second))
                denominator += cross
            }
            return abs(mass * numerator / (6 * denominator))
        }
    }

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
        case let .polygon(vertices):
            try Self.validatePolygon(vertices)
        case let .trapezoid(width, height, slope):
            guard
                width.isFinite,
                height.isFinite,
                slope.isFinite,
                width > 0,
                height > 0,
                (0..<1).contains(slope)
            else {
                throw MatterError.invalidShapeDimension
            }
        }
    }

    private static func validatePolygon(_ vertices: [Vector]) throws {
        guard vertices.count >= 3, vertices.allSatisfy(\.isFinite) else {
            throw MatterError.invalidPolygon
        }
        let signedArea = signedDoubleArea(of: vertices)
        guard signedArea.isFinite, abs(signedArea) > Float.ulpOfOne else {
            throw MatterError.invalidPolygon
        }

        var expectedSign: Float = 0
        for index in vertices.indices {
            let first = vertices[index]
            let second = vertices[(index + 1) % vertices.count]
            let third = vertices[(index + 2) % vertices.count]
            let turn = (second - first).cross(third - second)
            guard abs(turn) > Float.ulpOfOne else {
                throw MatterError.invalidPolygon
            }
            let sign: Float = turn > 0 ? 1 : -1
            if expectedSign == 0 {
                expectedSign = sign
            } else if sign != expectedSign {
                throw MatterError.nonConvexPolygon
            }
        }
    }

    private static func signedDoubleArea(of vertices: [Vector]) -> Float {
        guard vertices.count >= 3 else { return 0 }
        var result: Float = 0
        for index in vertices.indices {
            result += vertices[index].cross(vertices[(index + 1) % vertices.count])
        }
        return result
    }

    private static func rectangleVertices(width: Float, height: Float) -> [Vector] {
        let halfWidth = width / 2
        let halfHeight = height / 2
        return [
            Vector(x: -halfWidth, y: -halfHeight),
            Vector(x: halfWidth, y: -halfHeight),
            Vector(x: halfWidth, y: halfHeight),
            Vector(x: -halfWidth, y: halfHeight),
        ]
    }

    private static func trapezoidVertices(width: Float, height: Float, slope: Float) -> [Vector] {
        let halfWidth = width / 2
        let halfHeight = height / 2
        let topInset = width * slope / 2
        return [
            Vector(x: -halfWidth + topInset, y: -halfHeight),
            Vector(x: halfWidth - topInset, y: -halfHeight),
            Vector(x: halfWidth, y: halfHeight),
            Vector(x: -halfWidth, y: halfHeight),
        ]
    }
}

/// An axis-aligned bounding box used by collision broad phases and queries.
@frozen
public struct Bounds: Sendable, Hashable, Codable {
    /// The component-wise minimum corner.
    public let minimum: Vector

    /// The component-wise maximum corner.
    public let maximum: Vector

    /// Creates bounds with ordered finite corners.
    public init(minimum: Vector, maximum: Vector) {
        precondition(minimum.isFinite && maximum.isFinite)
        precondition(minimum.x <= maximum.x && minimum.y <= maximum.y)
        self.minimum = minimum
        self.maximum = maximum
    }

    /// Creates the smallest bounds containing at least one finite point.
    public init(containing points: [Vector]) {
        precondition(!points.isEmpty && points.allSatisfy(\.isFinite))
        var minimum = points[0]
        var maximum = points[0]
        for point in points.dropFirst() {
            minimum.x = min(minimum.x, point.x)
            minimum.y = min(minimum.y, point.y)
            maximum.x = max(maximum.x, point.x)
            maximum.y = max(maximum.y, point.y)
        }
        self.minimum = minimum
        self.maximum = maximum
    }

    /// The box width.
    public var width: Float {
        maximum.x - minimum.x
    }

    /// The box height.
    public var height: Float {
        maximum.y - minimum.y
    }

    /// The box center.
    public var center: Vector {
        (minimum + maximum) / 2
    }

    /// Returns whether a point lies on or within the box.
    public func contains(_ point: Vector) -> Bool {
        point.x >= minimum.x && point.x <= maximum.x
            && point.y >= minimum.y && point.y <= maximum.y
    }

    /// Returns whether this box overlaps or touches another box.
    public func overlaps(_ other: Self) -> Bool {
        maximum.x >= other.minimum.x && minimum.x <= other.maximum.x
            && maximum.y >= other.minimum.y && minimum.y <= other.maximum.y
    }

    /// Returns bounds translated by a finite offset.
    public func translated(by offset: Vector) -> Self {
        precondition(offset.isFinite)
        return Self(minimum: minimum + offset, maximum: maximum + offset)
    }

    /// Returns bounds expanded equally in every direction.
    public func expanded(by amount: Float) -> Self {
        precondition(amount.isFinite && amount >= 0)
        let offset = Vector(x: amount, y: amount)
        return Self(minimum: minimum - offset, maximum: maximum + offset)
    }
}
