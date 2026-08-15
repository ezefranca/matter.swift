import Testing

@testable import Matter

@Suite("Matter world queries")
struct MatterWorldQueryTests {
    @Test("Point queries use exact circle and polygon geometry")
    func pointQueries() throws {
        var world = World()
        let circle = try world.add(Bodies.circle(at: .zero, radius: 2))
        let rectangle = try world.add(
            BodyDefinition(
                shape: .rectangle(width: 4, height: 2),
                position: Vector(x: 5, y: 0),
                angle: .pi / 4
            )
        )
        let clockwise = try world.add(
            Bodies.vertices(
                at: Vector(x: 10, y: 0),
                vertices: [
                    Vector(x: -1, y: -1), Vector(x: -1, y: 1),
                    Vector(x: 1, y: 1), Vector(x: 1, y: -1),
                ]
            )
        )

        #expect(try WorldQuery.bodies(at: .zero, in: world).map(\.id) == [circle])
        #expect(try WorldQuery.bodies(at: Vector(x: 2, y: 0), in: world).map(\.id) == [circle])
        #expect(try WorldQuery.bodies(at: Vector(x: 5, y: 0), in: world).map(\.id) == [rectangle])
        #expect(try WorldQuery.bodies(at: Vector(x: 10, y: 1), in: world).map(\.id) == [clockwise])
        #expect(try WorldQuery.bodies(at: Vector(x: 20, y: 20), in: world).isEmpty)
        #expect(throws: MatterError.invalidVector) {
            try WorldQuery.bodies(at: Vector(x: .nan, y: 0), in: world)
        }
    }

    @Test("Region queries use current AABBs and preserve world order")
    func regionQueries() throws {
        var world = World()
        let first = try world.add(Bodies.circle(at: .zero, radius: 1))
        let second = try world.add(Bodies.rectangle(at: Vector(x: 3, y: 0), width: 2, height: 2))
        _ = try world.add(Bodies.circle(at: Vector(x: 20, y: 0), radius: 1))
        let region = Bounds(
            minimum: Vector(x: -1, y: -1),
            maximum: Vector(x: 2, y: 1)
        )

        #expect(WorldQuery.bodies(in: region, world: world).map(\.id) == [first, second])
    }

    @Test("Raycasts report nearest circle and polygon surfaces")
    func raycastHits() throws {
        var world = World()
        let circle = try world.add(Bodies.circle(at: .zero, radius: 1))
        let rectangle = try world.add(
            Bodies.rectangle(at: Vector(x: 4, y: 0), width: 2, height: 2)
        )
        let hits = try WorldQuery.raycast(
            from: Vector(x: -3, y: 0),
            to: Vector(x: 6, y: 0),
            in: world
        )

        #expect(hits.map(\.body) == [circle, rectangle])
        #expect(hits[0].point == Vector(x: -1, y: 0))
        #expect(hits[0].normal == Vector(x: -1, y: 0))
        #expect(abs(hits[0].distance - 2) < 0.000_01)
        #expect(abs(hits[0].fraction - (2.0 / 9.0)) < 0.000_01)
        #expect(hits[1].point == Vector(x: 3, y: 0))
        #expect(hits[1].normal == Vector(x: -1, y: 0))
    }

    @Test("Raycasts handle inside starts, tangency, reverse direction, and misses")
    func raycastBoundariesAndMisses() throws {
        var world = World()
        let circle = try world.add(Bodies.circle(at: .zero, radius: 1))
        let clockwise = try world.add(
            Bodies.vertices(
                at: Vector(x: 4, y: 0),
                vertices: [
                    Vector(x: -1, y: -1), Vector(x: -1, y: 1),
                    Vector(x: 1, y: 1), Vector(x: 1, y: -1),
                ]
            )
        )

        var hits = try WorldQuery.raycast(from: .zero, to: Vector(x: 10, y: 0), in: world)
        #expect(hits[0].body == circle)
        #expect(hits[0].fraction == 0)
        #expect(hits[0].normal == Vector(x: -1, y: 0))

        hits = try WorldQuery.raycast(
            from: Vector(x: 0.5, y: 0),
            to: Vector(x: 10, y: 0),
            in: world
        )
        #expect(hits[0].body == circle)
        #expect(hits[0].normal == Vector(x: -1, y: 0))

        hits = try WorldQuery.raycast(
            from: Vector(x: 4, y: 0),
            to: Vector(x: -4, y: 0),
            in: world
        )
        #expect(hits[0].body == clockwise)
        #expect(hits[0].normal == Vector(x: 1, y: 0))

        hits = try WorldQuery.raycast(
            from: Vector(x: -3, y: 1),
            to: Vector(x: 3, y: 1),
            in: world
        )
        #expect(hits.first?.body == circle)

        #expect(
            try WorldQuery.raycast(
                from: Vector(x: -3, y: 3),
                to: Vector(x: 3, y: 3),
                in: world
            ).isEmpty
        )
        #expect(
            try WorldQuery.raycast(
                from: Vector(x: 10, y: 0),
                to: Vector(x: 12, y: 0),
                in: world
            ).isEmpty
        )
    }

    @Test("Equal-distance ray hits use stable body identifiers")
    func raycastTieOrdering() throws {
        var world = World()
        let first = try world.add(Bodies.circle(at: .zero, radius: 1))
        let second = try world.add(Bodies.circle(at: .zero, radius: 1))

        let hits = try WorldQuery.raycast(
            from: Vector(x: -2, y: 0),
            to: Vector(x: 2, y: 0),
            in: world
        )

        #expect(hits.map(\.body) == [first, second])
    }

    @Test("Raycast validation rejects nonfinite and zero-length segments")
    func invalidRays() throws {
        let world = World()
        #expect(throws: MatterError.invalidRay) {
            try WorldQuery.raycast(from: .zero, to: .zero, in: world)
        }
        #expect(throws: MatterError.invalidRay) {
            try WorldQuery.raycast(from: Vector(x: .infinity, y: 0), to: .zero, in: world)
        }
    }
}
