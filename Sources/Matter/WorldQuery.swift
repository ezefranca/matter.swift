/// One nearest intersection between a finite ray segment and a body.
@frozen
public struct RaycastHit: Sendable, Hashable, Codable {
    /// The intersected body's stable identifier.
    public let body: BodyID

    /// The world-space intersection point.
    public let point: Vector

    /// A unit surface normal oriented against the ray direction.
    public let normal: Vector

    /// Distance from the ray start to the intersection.
    public let distance: Float

    /// Fractional progress along the segment, in `0...1`.
    public let fraction: Float

    init(body: BodyID, point: Vector, normal: Vector, distance: Float, fraction: Float) {
        self.body = body
        self.point = point
        self.normal = normal
        self.distance = distance
        self.fraction = fraction
    }
}

/// Stateless spatial queries over immutable world snapshots.
@frozen
public enum WorldQuery {
    /// Returns bodies whose exact current shape contains a world-space point.
    public static func bodies(at point: Vector, in world: World) throws -> [Body] {
        guard point.isFinite else { throw MatterError.invalidVector }
        return world.bodies.filter { contains(point, body: $0) }
    }

    /// Returns bodies whose axis-aligned bounds overlap a query region.
    public static func bodies(in bounds: Bounds, world: World) -> [Body] {
        world.bodies.filter { $0.bounds.overlaps(bounds) }
    }

    /// Intersects a finite segment with every body and returns stable nearest hits.
    ///
    /// Each body contributes at most one hit. Results order by distance and then
    /// by body identifier.
    ///
    /// - Throws: ``MatterError/invalidRay`` for nonfinite or equal endpoints.
    public static func raycast(
        from start: Vector,
        to end: Vector,
        in world: World
    ) throws -> [RaycastHit] {
        let direction = end - start
        guard start.isFinite, end.isFinite, direction.lengthSquared > 0 else {
            throw MatterError.invalidRay
        }
        let length = direction.length
        return world.bodies.compactMap { body in
            let result = body.collisionParts.compactMap { part in
                hit(start: start, direction: direction, body: part)
            }.min { $0.fraction < $1.fraction }
            return result.map {
                RaycastHit(
                    body: body.id,
                    point: $0.point,
                    normal: $0.normal,
                    distance: length * $0.fraction,
                    fraction: $0.fraction
                )
            }
        }.sorted { lhs, rhs in
            lhs.distance == rhs.distance ? lhs.body < rhs.body : lhs.distance < rhs.distance
        }
    }
}

private extension WorldQuery {
    static let tolerance: Float = 0.000_01

    static func contains(_ point: Vector, body: Body) -> Bool {
        if case .compound = body.shape {
            return body.collisionParts.contains { contains(point, body: $0) }
        }
        switch body.shape {
        case let .circle(radius):
            return (point - body.position).lengthSquared <= radius * radius
        default:
            let vertices = body.vertices
            var expectedSign: Float = 0
            for index in vertices.indices {
                let edge = vertices[(index + 1) % vertices.count] - vertices[index]
                let side = edge.cross(point - vertices[index])
                if abs(side) <= tolerance {
                    continue
                }
                let sign: Float = side > 0 ? 1 : -1
                if expectedSign == 0 {
                    expectedSign = sign
                } else if sign != expectedSign {
                    return false
                }
            }
            return true
        }
    }

    static func hit(
        start: Vector,
        direction: Vector,
        body: Body
    ) -> (fraction: Float, point: Vector, normal: Vector)? {
        switch body.shape {
        case let .circle(radius):
            circleHit(start: start, direction: direction, body: body, radius: radius)
        default:
            polygonHit(start: start, direction: direction, body: body)
        }
    }

    static func circleHit(
        start: Vector,
        direction: Vector,
        body: Body,
        radius: Float
    ) -> (fraction: Float, point: Vector, normal: Vector)? {
        let offset = start - body.position
        if offset.lengthSquared <= radius * radius {
            return (0, start, orientedNormal(offset.normalized(), against: direction))
        }

        let a = direction.dot(direction)
        let b = 2 * offset.dot(direction)
        let c = offset.dot(offset) - radius * radius
        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0 else { return nil }
        let root = discriminant.squareRoot()
        let first = (-b - root) / (2 * a)
        let second = (-b + root) / (2 * a)
        let fraction = [first, second].filter { (0...1).contains($0) }.min()
        guard let fraction else { return nil }
        let point = start + direction * fraction
        let normal = orientedNormal((point - body.position).normalized(), against: direction)
        return (fraction, point, normal)
    }

    static func polygonHit(
        start: Vector,
        direction: Vector,
        body: Body
    ) -> (fraction: Float, point: Vector, normal: Vector)? {
        if contains(start, body: body) {
            return (0, start, orientedNormal(.zero, against: direction))
        }

        let vertices = body.vertices
        let orientation: Float = signedDoubleArea(vertices) >= 0 ? 1 : -1
        var hits: [(fraction: Float, point: Vector, normal: Vector)] = []
        for index in vertices.indices {
            let edgeStart = vertices[index]
            let edge = vertices[(index + 1) % vertices.count] - edgeStart
            let denominator = direction.cross(edge)
            guard abs(denominator) > tolerance else { continue }
            let offset = edgeStart - start
            let fraction = offset.cross(edge) / denominator
            let edgeFraction = offset.cross(direction) / denominator
            guard (0...1).contains(fraction), (0...1).contains(edgeFraction) else { continue }
            let outward = Vector(x: orientation * edge.y, y: -orientation * edge.x).normalized()
            hits.append(
                (
                    fraction,
                    start + direction * fraction,
                    orientedNormal(outward, against: direction)
                )
            )
        }
        return hits.min { $0.fraction < $1.fraction }
    }

    static func orientedNormal(_ proposed: Vector, against direction: Vector) -> Vector {
        let normal = proposed.lengthSquared > tolerance ? proposed : -direction.normalized()
        return normal.dot(direction) > 0 ? -normal : normal
    }

    static func signedDoubleArea(_ vertices: [Vector]) -> Float {
        vertices.indices.reduce(into: 0) { area, index in
            area += vertices[index].cross(vertices[(index + 1) % vertices.count])
        }
    }
}
