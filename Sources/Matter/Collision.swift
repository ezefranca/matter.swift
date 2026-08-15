import Foundation

/// A canonical pair of distinct body identifiers.
///
/// The lower identifier is always stored first so pairs have stable equality,
/// hashing, serialization, and ordering independent of detection order.
@frozen
public struct BodyPair: Sendable, Hashable, Codable, Comparable {
    /// The lower body identifier.
    public let first: BodyID

    /// The higher body identifier.
    public let second: BodyID

    /// Creates a canonical pair, or returns `nil` for two equal identifiers.
    public init?(_ first: BodyID, _ second: BodyID) {
        guard first != second else { return nil }
        self.first = min(first, second)
        self.second = max(first, second)
    }

    /// Orders pairs lexicographically by their canonical identifiers.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.first == rhs.first ? lhs.second < rhs.second : lhs.first < rhs.first
    }
}

/// One deterministic point in a collision contact manifold.
@frozen
public struct ContactFeatureID: Sendable, Hashable, Codable, Comparable {
    /// The selected primitive-part index on ``BodyPair/first``.
    public let firstPart: Int

    /// The selected primitive-part index on ``BodyPair/second``.
    public let secondPart: Int

    /// The stable contact index within that primitive manifold.
    public let contact: Int

    init(firstPart: Int, secondPart: Int, contact: Int) {
        self.firstPart = firstPart
        self.secondPart = secondPart
        self.contact = contact
    }

    /// Orders features lexicographically by primitive and contact indices.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.firstPart != rhs.firstPart { return lhs.firstPart < rhs.firstPart }
        if lhs.secondPart != rhs.secondPart { return lhs.secondPart < rhs.secondPart }
        return lhs.contact < rhs.contact
    }
}

/// One deterministic point in a collision contact manifold.
@frozen
public struct CollisionContact: Sendable, Hashable, Codable {
    /// Stable primitive and manifold indices used to persist solver impulses.
    public let featureID: ContactFeatureID

    /// The world-space contact position.
    public let position: Vector

    /// The nonnegative overlap depth represented by the manifold.
    public let penetration: Float

    init(featureID: ContactFeatureID, position: Vector, penetration: Float) {
        self.featureID = featureID
        self.position = position
        self.penetration = penetration
    }
}

/// A narrow-phase collision between two bodies.
@frozen
public struct Collision: Sendable, Hashable, Codable {
    /// The canonical identities of the colliding bodies.
    public let pair: BodyPair

    /// The unit normal pointing from ``BodyPair/first`` to ``BodyPair/second``.
    public let normal: Vector

    /// The smallest nonnegative separating distance.
    public let penetration: Float

    /// One or two deterministic world-space contact points.
    public let contacts: [CollisionContact]

    /// Whether either body is a sensor and must not receive response impulses.
    public let isSensor: Bool

    init(
        pair: BodyPair,
        normal: Vector,
        penetration: Float,
        contacts: [CollisionContact],
        isSensor: Bool
    ) {
        self.pair = pair
        self.normal = normal
        self.penetration = penetration
        self.contacts = contacts
        self.isSensor = isSensor
    }
}

/// Deterministic broad- and narrow-phase collision queries.
///
/// The broad phase uses an x-axis sweep over current ``Body/bounds``. The
/// narrow phase uses exact circle intersection and separating-axis tests for
/// every convex primitive, including decomposed compound parts. Results are
/// canonical and sorted by body ID.
@frozen
public enum CollisionDetector {
    /// Returns filtered AABB-overlapping pairs in stable identifier order.
    public static func potentialPairs(in world: World) -> [BodyPair] {
        let sortedBodies = world.bodies.sorted { lhs, rhs in
            if lhs.bounds.minimum.x == rhs.bounds.minimum.x {
                return lhs.id < rhs.id
            }
            return lhs.bounds.minimum.x < rhs.bounds.minimum.x
        }

        var pairs: [BodyPair] = []
        for firstIndex in sortedBodies.indices {
            let first = sortedBodies[firstIndex]
            for secondIndex in sortedBodies.indices where secondIndex > firstIndex {
                let second = sortedBodies[secondIndex]
                if second.bounds.minimum.x > first.bounds.maximum.x {
                    break
                }
                guard
                    first.bounds.overlaps(second.bounds),
                    first.collisionFilter.allowsCollision(with: second.collisionFilter),
                    let pair = BodyPair(first.id, second.id)
                else {
                    continue
                }
                pairs.append(pair)
            }
        }
        return pairs.sorted()
    }

    /// Returns all current collisions in stable identifier order.
    public static func collisions(in world: World) -> [Collision] {
        return potentialPairs(in: world).compactMap { pair in
            let bodies = world.bodies
                .filter { $0.id == pair.first || $0.id == pair.second }
                .sorted { $0.id < $1.id }
            return collision(between: bodies[0], and: bodies[1])
        }
    }

    /// Tests two distinct, filter-compatible bodies using their current transforms.
    ///
    /// The returned normal always points from the lower body identifier to the
    /// higher identifier. Touching shapes produce a collision with zero penetration.
    public static func collision(between first: Body, and second: Body) -> Collision? {
        guard
            let pair = BodyPair(first.id, second.id),
            first.collisionFilter.allowsCollision(with: second.collisionFilter)
        else {
            return nil
        }

        let bodyA = pair.first == first.id ? first : second
        let bodyB = pair.second == second.id ? second : first
        guard bodyA.bounds.overlaps(bodyB.bounds) else { return nil }

        var selected: (firstPart: Int, secondPart: Int, result: NarrowPhaseResult)?
        for (firstPart, partA) in bodyA.collisionParts.enumerated() {
            for (secondPart, partB) in bodyB.collisionParts.enumerated()
            where partA.bounds.overlaps(partB.bounds) {
                guard let candidate = simpleCollision(partA, partB) else { continue }
                if selected.map({ candidate.penetration > $0.result.penetration + tolerance })
                    ?? true
                {
                    selected = (firstPart, secondPart, candidate)
                }
            }
        }

        guard let selected else { return nil }
        let contacts = selected.result.positions.enumerated().map { contact, position in
            CollisionContact(
                featureID: ContactFeatureID(
                    firstPart: selected.firstPart,
                    secondPart: selected.secondPart,
                    contact: contact
                ),
                position: position,
                penetration: selected.result.penetration
            )
        }
        return Collision(
            pair: pair,
            normal: selected.result.normal,
            penetration: selected.result.penetration,
            contacts: contacts,
            isSensor: bodyA.isSensor || bodyB.isSensor
        )
    }
}

private struct NarrowPhaseResult {
    let normal: Vector
    let penetration: Float
    let positions: [Vector]
}

private extension CollisionDetector {
    static let tolerance: Float = 0.000_01

    static func simpleCollision(_ bodyA: Body, _ bodyB: Body) -> NarrowPhaseResult? {
        switch (bodyA.shape, bodyB.shape) {
        case let (.circle(radiusA), .circle(radiusB)):
            circleCircle(bodyA, radiusA: radiusA, bodyB, radiusB: radiusB)
        default:
            separatingAxis(bodyA, bodyB)
        }
    }

    static func circleCircle(
        _ bodyA: Body,
        radiusA: Float,
        _ bodyB: Body,
        radiusB: Float
    ) -> NarrowPhaseResult? {
        let delta = bodyB.position - bodyA.position
        let distanceSquared = delta.lengthSquared
        let radiusSum = radiusA + radiusB
        guard distanceSquared <= radiusSum * radiusSum else { return nil }

        let distance = distanceSquared.squareRoot()
        let normal = distance > tolerance ? delta / distance : Vector(x: 1, y: 0)
        let penetration = max(0, radiusSum - distance)
        let surfaceA = bodyA.position + normal * radiusA
        let surfaceB = bodyB.position - normal * radiusB
        return NarrowPhaseResult(
            normal: normal,
            penetration: penetration,
            positions: [(surfaceA + surfaceB) / 2]
        )
    }

    static func separatingAxis(_ bodyA: Body, _ bodyB: Body) -> NarrowPhaseResult? {
        let verticesA = bodyA.vertices
        let verticesB = bodyB.vertices
        var axes = polygonAxes(verticesA) + polygonAxes(verticesB)

        if case .circle = bodyA.shape, !verticesB.isEmpty {
            axes.append(axisFromCircle(bodyA.position, toClosestVertexIn: verticesB))
        }
        if case .circle = bodyB.shape, !verticesA.isEmpty {
            axes.append(axisFromCircle(bodyB.position, toClosestVertexIn: verticesA))
        }
        axes.removeAll { $0.lengthSquared <= tolerance * tolerance }

        let centerDelta = bodyB.position - bodyA.position
        var bestAxis = Vector.zero
        var minimumOverlap = Float.infinity
        for proposedAxis in axes {
            var axis = proposedAxis.normalized()
            let projectionA = projection(of: bodyA, vertices: verticesA, onto: axis)
            let projectionB = projection(of: bodyB, vertices: verticesB, onto: axis)
            let overlap =
                min(projectionA.maximum, projectionB.maximum)
                - max(projectionA.minimum, projectionB.minimum)
            guard overlap >= -tolerance else { return nil }

            if centerDelta.dot(axis) < 0
                || (abs(centerDelta.dot(axis)) <= tolerance
                    && (axis.x < 0 || (abs(axis.x) <= tolerance && axis.y < 0)))
            {
                axis = -axis
            }
            if overlap < minimumOverlap {
                minimumOverlap = overlap
                bestAxis = axis
            }
        }

        let penetration = max(0, minimumOverlap)
        let positions: [Vector]
        if !verticesA.isEmpty, !verticesB.isEmpty {
            positions = polygonContacts(
                verticesA,
                verticesB,
                normal: bestAxis
            )
        } else {
            positions = [supportContact(bodyA, bodyB, normal: bestAxis)]
        }
        return NarrowPhaseResult(
            normal: bestAxis,
            penetration: penetration,
            positions: positions
        )
    }

    static func polygonAxes(_ vertices: [Vector]) -> [Vector] {
        guard vertices.count >= 2 else { return [] }
        return vertices.indices.map { index in
            let edge = vertices[(index + 1) % vertices.count] - vertices[index]
            return Vector(x: -edge.y, y: edge.x).normalized()
        }
    }

    static func axisFromCircle(_ center: Vector, toClosestVertexIn vertices: [Vector]) -> Vector {
        var closest = vertices[0]
        var minimumDistance = (closest - center).lengthSquared
        for vertex in vertices.dropFirst() {
            let distance = (vertex - center).lengthSquared
            if distance < minimumDistance {
                closest = vertex
                minimumDistance = distance
            }
        }
        return closest - center
    }

    static func projection(
        of body: Body,
        vertices: [Vector],
        onto axis: Vector
    ) -> (minimum: Float, maximum: Float) {
        if case let .circle(radius) = body.shape {
            let center = body.position.dot(axis)
            return (center - radius, center + radius)
        }
        let values = vertices.map { $0.dot(axis) }
        return extrema(of: values)
    }

    static func supportContact(_ bodyA: Body, _ bodyB: Body, normal: Vector) -> Vector {
        let pointA = supportPoint(on: bodyA, direction: normal)
        let pointB = supportPoint(on: bodyB, direction: -normal)
        return (pointA + pointB) / 2
    }

    static func supportPoint(on body: Body, direction: Vector) -> Vector {
        if case let .circle(radius) = body.shape {
            return body.position + direction * radius
        }
        let vertices = body.vertices
        let maximum = extrema(of: vertices.map { $0.dot(direction) }).maximum
        let supported = vertices.filter { abs($0.dot(direction) - maximum) <= tolerance }
        return supported.reduce(.zero, +) / Float(supported.count)
    }

    static func polygonContacts(
        _ verticesA: [Vector],
        _ verticesB: [Vector],
        normal: Vector
    ) -> [Vector] {
        let intersection = convexIntersection(subject: verticesA, clip: verticesB)
        let tangent = Vector(x: -normal.y, y: normal.x)
        let tangentExtrema = extrema(of: intersection.map { $0.dot(tangent) })
        let minimum = tangentExtrema.minimum
        let maximum = tangentExtrema.maximum
        let first = average(
            intersection.filter { abs($0.dot(tangent) - minimum) <= tolerance })
        guard maximum - minimum > tolerance else { return [first] }
        let second = average(
            intersection.filter { abs($0.dot(tangent) - maximum) <= tolerance })
        return [first, second]
    }

    static func average(_ points: [Vector]) -> Vector {
        points.reduce(.zero, +) / Float(points.count)
    }

    static func extrema(of values: [Float]) -> (minimum: Float, maximum: Float) {
        var minimum = values[0]
        var maximum = values[0]
        for value in values.dropFirst() {
            minimum = min(minimum, value)
            maximum = max(maximum, value)
        }
        return (minimum, maximum)
    }

    static func convexIntersection(subject: [Vector], clip: [Vector]) -> [Vector] {
        let orientation: Float = signedDoubleArea(clip) >= 0 ? 1 : -1
        var output = subject

        for clipIndex in clip.indices {
            let clipStart = clip[clipIndex]
            let clipEnd = clip[(clipIndex + 1) % clip.count]
            let clipEdge = clipEnd - clipStart
            let input = output
            output = []
            var previous = input[input.index(before: input.endIndex)]
            var previousInside = orientation * clipEdge.cross(previous - clipStart) >= -tolerance

            for current in input {
                let currentInside =
                    orientation * clipEdge.cross(current - clipStart) >= -tolerance
                if currentInside != previousInside {
                    output.append(
                        lineIntersection(
                            from: previous,
                            to: current,
                            clipStart: clipStart,
                            clipEdge: clipEdge
                        )
                    )
                }
                if currentInside {
                    output.append(current)
                }
                previous = current
                previousInside = currentInside
            }
        }
        return deduplicated(output)
    }

    static func lineIntersection(
        from start: Vector,
        to end: Vector,
        clipStart: Vector,
        clipEdge: Vector
    ) -> Vector {
        let direction = end - start
        let denominator = direction.cross(clipEdge)
        let amount = (clipStart - start).cross(clipEdge) / denominator
        return start + direction * amount
    }

    static func deduplicated(_ points: [Vector]) -> [Vector] {
        var result: [Vector] = []
        for point in points where !result.contains(where: { $0.distance(to: point) <= tolerance }) {
            result.append(point)
        }
        return result
    }

    static func signedDoubleArea(_ vertices: [Vector]) -> Float {
        vertices.indices.reduce(into: 0) { result, index in
            result += vertices[index].cross(vertices[(index + 1) % vertices.count])
        }
    }
}
