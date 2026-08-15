import Testing

@testable import Matter

@Suite("Matter collision detection")
struct MatterCollisionTests {
    @Test("Body pairs canonicalize identities and sort lexicographically")
    func bodyPairCanonicalization() throws {
        let one = BodyID(rawValue: 1)
        let two = BodyID(rawValue: 2)
        let three = BodyID(rawValue: 3)

        #expect(BodyPair(one, one) == nil)
        #expect(BodyPair(two, one)?.first == one)
        #expect(BodyPair(two, one)?.second == two)
        #expect(try #require(BodyPair(one, two)) < #require(BodyPair(one, three)))
        #expect(try #require(BodyPair(one, three)) < #require(BodyPair(two, three)))
    }

    @Test("Sweep and prune returns stable filtered AABB candidates")
    func broadPhaseCandidates() throws {
        var world = World()
        let first = try world.add(Bodies.circle(at: .zero, radius: 2))
        let second = try world.add(Bodies.circle(at: Vector(x: 3, y: 0), radius: 2))
        _ = try world.add(Bodies.circle(at: Vector(x: 20, y: 0), radius: 2))
        let fourth = try world.add(
            BodyDefinition(
                shape: .circle(radius: 2),
                position: Vector(x: 0, y: 1),
                collisionFilter: CollisionFilter(category: 0b10, mask: 0b10)
            )
        )
        let fifth = try world.add(
            BodyDefinition(
                shape: .circle(radius: 2),
                position: Vector(x: 0, y: 1),
                collisionFilter: CollisionFilter(category: 0b10, mask: 0b10)
            )
        )

        let pairs = CollisionDetector.potentialPairs(in: world)
        #expect(pairs == [BodyPair(first, second), BodyPair(fourth, fifth)])

        var denseWorld = World()
        for _ in 0..<32 {
            _ = try denseWorld.add(Bodies.circle(at: .zero, radius: 1))
        }
        let densePairs = CollisionDetector.potentialPairs(in: denseWorld)
        #expect(densePairs.count == 496)
        #expect(densePairs == densePairs.sorted())
    }

    @Test("Circle collisions include touching, overlap, and coincident centers")
    func circleCircleCollisions() throws {
        var world = World()
        let first = try world.add(Bodies.circle(at: .zero, radius: 2))
        let second = try world.add(Bodies.circle(at: Vector(x: 3, y: 0), radius: 2))
        let third = try world.add(Bodies.circle(at: Vector(x: 10, y: 0), radius: 1))
        let firstBody = try #require(world.body(withID: first))
        let secondBody = try #require(world.body(withID: second))
        let thirdBody = try #require(world.body(withID: third))

        let overlap = try #require(
            CollisionDetector.collision(
                between: secondBody,
                and: firstBody
            )
        )
        #expect(overlap.pair == BodyPair(first, second))
        #expect(overlap.normal == Vector(x: 1, y: 0))
        #expect(overlap.penetration == 1)
        #expect(
            overlap.contacts == [CollisionContact(position: Vector(x: 1.5, y: 0), penetration: 1)])
        #expect(!overlap.isSensor)
        #expect(
            CollisionDetector.collision(
                between: firstBody,
                and: thirdBody
            ) == nil
        )

        var diagonalWorld = World()
        _ = try diagonalWorld.add(Bodies.circle(at: .zero, radius: 2))
        _ = try diagonalWorld.add(Bodies.circle(at: Vector(x: 3, y: 3), radius: 2))
        #expect(CollisionDetector.potentialPairs(in: diagonalWorld).count == 1)
        #expect(CollisionDetector.collisions(in: diagonalWorld).isEmpty)

        try world.updateBody(withID: second) { try $0.setPosition(Vector(x: 4, y: 0)) }
        let touching = try #require(CollisionDetector.collisions(in: world).first)
        #expect(touching.penetration == 0)

        try world.updateBody(withID: second) { try $0.setPosition(.zero) }
        let coincident = try #require(CollisionDetector.collisions(in: world).first)
        #expect(coincident.normal == Vector(x: 1, y: 0))
        #expect(coincident.penetration == 4)
    }

    @Test("Circle-polygon SAT handles overlap, separation, rotation, and sensors")
    func circlePolygonCollisions() throws {
        var world = World()
        let circle = try world.add(
            BodyDefinition(
                shape: .circle(radius: 2), position: Vector(x: -2.5, y: 0), isSensor: true)
        )
        let rectangle = try world.add(
            BodyDefinition(
                shape: .rectangle(width: 4, height: 4),
                position: .zero,
                angle: .pi / 4
            )
        )

        var collision = try #require(CollisionDetector.collisions(in: world).first)
        #expect(collision.pair == BodyPair(circle, rectangle))
        #expect(collision.normal.length > 0.999)
        #expect(collision.penetration > 0)
        #expect(collision.contacts.count == 1)
        #expect(collision.isSensor)

        try world.updateBody(withID: circle) { try $0.setPosition(Vector(x: -10, y: 0)) }
        #expect(CollisionDetector.collisions(in: world).isEmpty)

        try world.updateBody(withID: circle) { try $0.setPosition(.zero) }
        collision = try #require(CollisionDetector.collisions(in: world).first)
        #expect(collision.penetration > 1.9)
        #expect(collision.contacts[0].position.isFinite)

        var reversedWorld = World()
        _ = try reversedWorld.add(Bodies.rectangle(at: .zero, width: 4, height: 4))
        _ = try reversedWorld.add(Bodies.circle(at: Vector(x: 2.5, y: 0), radius: 1))
        #expect(CollisionDetector.collisions(in: reversedWorld).count == 1)

        var cornerWorld = World()
        _ = try cornerWorld.add(Bodies.rectangle(at: .zero, width: 4, height: 4))
        _ = try cornerWorld.add(Bodies.circle(at: Vector(x: 2.75, y: 2.75), radius: 1))
        #expect(CollisionDetector.potentialPairs(in: cornerWorld).count == 1)
        #expect(CollisionDetector.collisions(in: cornerWorld).isEmpty)
    }

    @Test("Polygon SAT produces deterministic one- or two-point manifolds")
    func polygonPolygonCollisions() throws {
        var world = World()
        let first = try world.add(Bodies.rectangle(at: .zero, width: 4, height: 4))
        let second = try world.add(
            Bodies.rectangle(at: Vector(x: 3, y: 0), width: 4, height: 4)
        )
        let collision = try #require(CollisionDetector.collisions(in: world).first)

        #expect(collision.pair == BodyPair(first, second))
        #expect(collision.normal == Vector(x: 1, y: 0))
        #expect(collision.penetration == 1)
        #expect(collision.contacts.count == 2)
        #expect(collision.contacts[0].position == Vector(x: 1.5, y: -2))
        #expect(collision.contacts[1].position == Vector(x: 1.5, y: 2))

        try world.updateBody(withID: second) { try $0.setPosition(Vector(x: 4, y: 4)) }
        let cornerTouch = try #require(CollisionDetector.collisions(in: world).first)
        #expect(cornerTouch.penetration == 0)
        #expect(cornerTouch.contacts.count == 1)

        try world.updateBody(withID: second) { body in
            try body.setPosition(Vector(x: 2, y: 2))
            try body.setAngle(.pi / 4)
        }
        let rotated = try #require(CollisionDetector.collisions(in: world).first)
        #expect((1...2).contains(rotated.contacts.count))
        #expect(rotated.contacts.allSatisfy { $0.position.isFinite })

        try world.updateBody(withID: second) { try $0.setPosition(Vector(x: 20, y: 20)) }
        #expect(CollisionDetector.collisions(in: world).isEmpty)
    }

    @Test("Clockwise vertex order and containment remain detectable")
    func clockwiseAndContainedPolygons() throws {
        var world = World()
        let outer = try world.add(Bodies.rectangle(at: .zero, width: 10, height: 10))
        let inner = try world.add(
            Bodies.vertices(
                at: .zero,
                vertices: [
                    Vector(x: -1, y: -1), Vector(x: -1, y: 1),
                    Vector(x: 1, y: 1), Vector(x: 1, y: -1),
                ]
            )
        )
        let collision = try #require(CollisionDetector.collisions(in: world).first)
        #expect(collision.pair == BodyPair(outer, inner))
        #expect(collision.penetration == 2)
        #expect(!collision.contacts.isEmpty)
    }

    @Test("Direct detection rejects identical and filter-incompatible bodies")
    func directDetectionValidation() throws {
        var world = World()
        let first = try world.add(
            BodyDefinition(
                shape: .circle(radius: 2),
                position: .zero,
                collisionFilter: CollisionFilter(category: 0b1, mask: 0b1)
            )
        )
        let second = try world.add(
            BodyDefinition(
                shape: .circle(radius: 2),
                position: .zero,
                collisionFilter: CollisionFilter(category: 0b10, mask: 0b10)
            )
        )
        let bodyA = try #require(world.body(withID: first))
        let bodyB = try #require(world.body(withID: second))

        #expect(CollisionDetector.collision(between: bodyA, and: bodyA) == nil)
        #expect(CollisionDetector.collision(between: bodyA, and: bodyB) == nil)
    }
}
