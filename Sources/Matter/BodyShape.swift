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

/// One primitive shape and transform within a compound body.
@frozen
public struct CompoundPart: Sendable, Hashable, Codable {
    /// Convex primitive geometry expressed in the part's local coordinates.
    public var shape: BodyShape

    /// The part origin relative to the owning body origin.
    public var position: Vector

    /// The part's clockwise rotation relative to the owning body angle.
    public var angle: Float

    /// Creates a validated compound part.
    ///
    /// Nested compound shapes are deliberately unsupported.
    public init(shape: BodyShape, position: Vector = .zero, angle: Float = 0) throws {
        self.shape = shape
        self.position = position
        self.angle = angle
        try validate()
    }

    func validate() throws {
        guard position.isFinite, angle.isFinite else {
            throw MatterError.invalidCompound
        }
        guard case .compound = shape else {
            try shape.validate()
            return
        }
        throw MatterError.invalidCompound
    }
}

/// Collision geometry expressed in body-local coordinates.
@frozen
public indirect enum BodyShape: Sendable, Hashable, Codable {
    /// A circle with a finite radius greater than zero.
    case circle(radius: Float)

    /// A rectangle with finite width and height greater than zero.
    case rectangle(width: Float, height: Float)

    /// A convex polygon containing at least three finite local vertices.
    case polygon(vertices: [Vector])

    /// An isosceles trapezoid whose slope is in `0..<1`.
    case trapezoid(width: Float, height: Float, slope: Float)

    /// Two or more transformed convex primitive parts sharing one rigid body.
    case compound(parts: [CompoundPart])

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
        case let .compound(parts):
            parts.reduce(into: 0) { $0 += $1.shape.area }
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
        case let .compound(parts):
            parts.flatMap { part in
                part.shape.localVertices.map {
                    $0.rotated(by: part.angle) + part.position
                }
            }
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
        case let .compound(parts):
            let totalArea = area
            return parts.reduce(into: 0) { result, part in
                let partMass = mass * part.shape.area / totalArea
                result +=
                    part.shape.inertia(forMass: partMass)
                    + partMass * part.position.lengthSquared
            }
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
        case let .compound(parts):
            guard parts.count >= 2 else { throw MatterError.invalidCompound }
            try parts.forEach { try $0.validate() }
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

/// Deterministic ear-clipping decomposition for simple concave polygons.
@frozen
public enum ConcaveDecomposer {
    /// Splits a simple polygon into stable convex parts.
    ///
    /// Convex input returns one part. Concave input returns triangles in the
    /// deterministic order in which ears are removed. Holes, duplicate points,
    /// collinear adjacent edges, and self-intersections are rejected.
    public static func decompose(_ vertices: [Vector]) throws -> [CompoundPart] {
        try validateSimplePolygon(vertices)
        if isConvex(vertices) {
            return [try CompoundPart(shape: .polygon(vertices: vertices))]
        }

        let orientation: Float = signedDoubleArea(vertices) > 0 ? 1 : -1
        var indices = Array(vertices.indices)
        var triangles: [CompoundPart] = []
        while indices.count > 3 {
            // The two-ears theorem guarantees a result after simple-polygon
            // validation, and every removal preserves that invariant.
            let earOffset = indices.indices.dropFirst().reduce(indices.startIndex) {
                selected, candidate in
                if isEar(
                    at: selected,
                    indices: indices,
                    vertices: vertices,
                    orientation: orientation
                ) {
                    return selected
                }
                return candidate
            }
            let previous = indices[(earOffset + indices.count - 1) % indices.count]
            let current = indices[earOffset]
            let next = indices[(earOffset + 1) % indices.count]
            triangles.append(
                try CompoundPart(
                    shape: .polygon(vertices: [
                        vertices[previous], vertices[current], vertices[next],
                    ])
                )
            )
            indices.remove(at: earOffset)
        }
        triangles.append(
            try CompoundPart(shape: .polygon(vertices: indices.map { vertices[$0] }))
        )
        return triangles
    }
}

private extension ConcaveDecomposer {
    static let tolerance: Float = 0.000_001

    static func validateSimplePolygon(_ vertices: [Vector]) throws {
        guard vertices.count >= 3, vertices.allSatisfy(\.isFinite) else {
            throw MatterError.invalidPolygon
        }
        guard abs(signedDoubleArea(vertices)) > tolerance else {
            throw MatterError.invalidPolygon
        }
        for first in vertices.indices {
            let second = (first + 1) % vertices.count
            guard (vertices[second] - vertices[first]).lengthSquared > tolerance * tolerance else {
                throw MatterError.invalidPolygon
            }
        }
        for first in vertices.indices {
            let second = (first + 1) % vertices.count
            let third = (first + 2) % vertices.count
            guard
                abs((vertices[second] - vertices[first]).cross(vertices[third] - vertices[second]))
                    > tolerance
            else {
                throw MatterError.invalidPolygon
            }
            for otherFirst in vertices.indices where otherFirst > first {
                let otherSecond = (otherFirst + 1) % vertices.count
                guard
                    first != otherSecond,
                    second != otherFirst,
                    !segmentsIntersect(
                        vertices[first],
                        vertices[second],
                        vertices[otherFirst],
                        vertices[otherSecond]
                    )
                else {
                    if first != otherSecond, second != otherFirst {
                        throw MatterError.invalidPolygon
                    }
                    continue
                }
            }
        }
    }

    static func isConvex(_ vertices: [Vector]) -> Bool {
        let orientation: Float = signedDoubleArea(vertices) > 0 ? 1 : -1
        return vertices.indices.allSatisfy { index in
            let first = vertices[index]
            let second = vertices[(index + 1) % vertices.count]
            let third = vertices[(index + 2) % vertices.count]
            return (second - first).cross(third - second) * orientation > tolerance
        }
    }

    static func isEar(
        at offset: Int,
        indices: [Int],
        vertices: [Vector],
        orientation: Float
    ) -> Bool {
        let previous = indices[(offset + indices.count - 1) % indices.count]
        let current = indices[offset]
        let next = indices[(offset + 1) % indices.count]
        let first = vertices[previous]
        let second = vertices[current]
        let third = vertices[next]
        guard (second - first).cross(third - second) * orientation > tolerance else {
            return false
        }
        return !indices.contains { index in
            guard index != previous, index != current, index != next else { return false }
            return point(
                vertices[index], liesInTriangle: first, second, third, orientation: orientation)
        }
    }

    static func point(
        _ point: Vector,
        liesInTriangle first: Vector,
        _ second: Vector,
        _ third: Vector,
        orientation: Float
    ) -> Bool {
        let edges = [
            (second - first).cross(point - first),
            (third - second).cross(point - second),
            (first - third).cross(point - third),
        ]
        return edges.allSatisfy { $0 * orientation >= -tolerance }
    }

    static func segmentsIntersect(
        _ first: Vector,
        _ second: Vector,
        _ otherFirst: Vector,
        _ otherSecond: Vector
    ) -> Bool {
        let firstDirection = orientation(first, second, otherFirst)
        let secondDirection = orientation(first, second, otherSecond)
        let thirdDirection = orientation(otherFirst, otherSecond, first)
        let fourthDirection = orientation(otherFirst, otherSecond, second)
        return firstDirection * secondDirection <= tolerance
            && thirdDirection * fourthDirection <= tolerance
    }

    static func orientation(_ first: Vector, _ second: Vector, _ third: Vector) -> Float {
        (second - first).cross(third - first)
    }

    static func signedDoubleArea(_ vertices: [Vector]) -> Float {
        vertices.indices.reduce(into: 0) { result, index in
            result += vertices[index].cross(vertices[(index + 1) % vertices.count])
        }
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
