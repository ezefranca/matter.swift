import Foundation
import Testing

@testable import Matter

@Suite("Matter compound and concave bodies")
struct MatterCompoundBodyTests {
    private let concaveVertices = [
        Vector(x: -2, y: -2),
        Vector(x: 2, y: -2),
        Vector(x: 2, y: 0),
        Vector(x: 0, y: 0),
        Vector(x: 0, y: 2),
        Vector(x: -2, y: 2),
    ]

    @Test("Compound parts and shapes reject invalid structure")
    func compoundValidation() throws {
        #expect(throws: MatterError.invalidCompound) {
            try CompoundPart(
                shape: .circle(radius: 1),
                position: Vector(x: .nan, y: 0)
            )
        }
        #expect(throws: MatterError.invalidCompound) {
            try CompoundPart(shape: .circle(radius: 1), angle: .infinity)
        }
        #expect(throws: MatterError.invalidShapeDimension) {
            try CompoundPart(shape: .circle(radius: 0))
        }
        let valid = try CompoundPart(shape: .circle(radius: 1))
        #expect(throws: MatterError.invalidCompound) {
            try BodyDefinition(shape: .compound(parts: [valid]), position: .zero)
        }
        #expect(throws: MatterError.invalidCompound) {
            try CompoundPart(shape: .compound(parts: [valid, valid]))
        }

        var corrupted = valid
        corrupted.shape = .compound(parts: [valid, valid])
        #expect(throws: MatterError.invalidCompound) {
            try Bodies.compound(at: .zero, parts: [valid, corrupted])
        }
    }

    @Test("Compound geometry combines area, inertia, vertices, and transformed bounds")
    func compoundGeometry() throws {
        let circle = try CompoundPart(
            shape: .circle(radius: 1),
            position: Vector(x: -2, y: 0)
        )
        let rectangle = try CompoundPart(
            shape: .rectangle(width: 2, height: 4),
            position: Vector(x: 2, y: 0),
            angle: .pi / 2
        )
        let definition = try Bodies.compound(
            at: Vector(x: 10, y: 20),
            parts: [circle, rectangle],
            angle: .pi / 2,
            mass: 11
        )
        guard case let .compound(parts) = definition.shape else {
            Issue.record("Expected compound geometry")
            return
        }
        #expect(parts == [circle, rectangle])
        #expect(abs(definition.shape.area - (Float.pi + 8)) < 0.000_01)
        #expect(definition.shape.localVertices.count == 4)
        #expect(definition.shape.inertia(forMass: 11).isFinite)

        var world = World()
        let identifier = try world.add(definition)
        let body = try #require(world.body(withID: identifier))
        #expect(body.vertices.count == 4)
        #expect(abs(body.bounds.minimum.x - 9) < 0.000_01)
        #expect(abs(body.bounds.maximum.x - 11) < 0.000_01)
        #expect(abs(body.bounds.minimum.y - 17) < 0.000_01)
        #expect(abs(body.bounds.maximum.y - 24) < 0.000_01)
        #expect(body.centerOfMass == Vector(x: 10, y: 20))
    }

    @Test("Convex input remains one polygon in either winding")
    func convexDecomposition() throws {
        let square = [
            Vector(x: -1, y: -1), Vector(x: 1, y: -1),
            Vector(x: 1, y: 1), Vector(x: -1, y: 1),
        ]
        let forward = try ConcaveDecomposer.decompose(square)
        let reversedSquare = Array(square.reversed())
        let reverse = try ConcaveDecomposer.decompose(reversedSquare)
        #expect(forward.count == 1)
        #expect(reverse.count == 1)
        #expect(forward[0].shape == .polygon(vertices: square))
        #expect(reverse[0].shape == .polygon(vertices: reversedSquare))

        let definition = try Bodies.fromVertices(at: .zero, vertices: square)
        #expect(definition.shape == .polygon(vertices: square))
        #expect(definition.label == "Polygon")
    }

    @Test("Ear clipping is deterministic for clockwise and counterclockwise concavity")
    func concaveDecomposition() throws {
        let forward = try ConcaveDecomposer.decompose(concaveVertices)
        let reverse = try ConcaveDecomposer.decompose(Array(concaveVertices.reversed()))
        let reflexFirst = Array(concaveVertices[3...]) + Array(concaveVertices[..<3])
        let rotated = try ConcaveDecomposer.decompose(reflexFirst)
        #expect(forward.count == concaveVertices.count - 2)
        #expect(reverse.count == concaveVertices.count - 2)
        #expect(forward.allSatisfy { $0.shape.area > 0 })
        #expect(reverse.allSatisfy { $0.shape.area > 0 })
        #expect(rotated.count == concaveVertices.count - 2)
        #expect(abs(forward.reduce(0) { $0 + $1.shape.area } - 12) < 0.000_01)
        #expect(abs(reverse.reduce(0) { $0 + $1.shape.area } - 12) < 0.000_01)
        #expect(try ConcaveDecomposer.decompose(concaveVertices) == forward)

        let definition = try Bodies.fromVertices(
            at: Vector(x: 3, y: 4),
            vertices: concaveVertices,
            mass: 6,
            isStatic: true
        )
        guard case let .compound(parts) = definition.shape else {
            Issue.record("Expected decomposed compound geometry")
            return
        }
        #expect(parts == forward)
        #expect(definition.position == Vector(x: 3, y: 4))
        #expect(definition.mass == 6)
        #expect(definition.isStatic)
        #expect(definition.label == "Concave Compound")
    }

    @Test("Decomposition rejects malformed and nonsimple polygons")
    func invalidDecomposition() {
        let cases: [[Vector]] = [
            [.zero, Vector(x: 1, y: 0)],
            [.zero, Vector(x: .nan, y: 0), Vector(x: 0, y: 1)],
            [.zero, Vector(x: 1, y: 0), .zero, Vector(x: 0, y: 1)],
            [.zero, Vector(x: 1, y: 0), Vector(x: 1, y: 0), Vector(x: 0, y: 1)],
            [.zero, Vector(x: 1, y: 0), Vector(x: 2, y: 0), Vector(x: 0, y: 1)],
            [
                Vector(x: 0, y: 0), Vector(x: 4, y: 0), Vector(x: 0, y: 4),
                Vector(x: 4, y: 4), Vector(x: 2, y: 1),
            ],
        ]
        for vertices in cases {
            #expect(throws: MatterError.invalidPolygon) {
                try ConcaveDecomposer.decompose(vertices)
            }
        }
    }

    @Test("Concave hit testing and raycasts preserve empty notches")
    func spatialQueries() throws {
        var world = World()
        let concave = try world.add(
            Bodies.fromVertices(at: .zero, vertices: concaveVertices)
        )
        #expect(try WorldQuery.bodies(at: Vector(x: -1, y: 1), in: world).map(\.id) == [concave])
        #expect(try WorldQuery.bodies(at: Vector(x: 1, y: 1), in: world).isEmpty)

        var hits = try WorldQuery.raycast(
            from: Vector(x: -3, y: 1),
            to: Vector(x: 3, y: 1),
            in: world
        )
        #expect(hits.map(\.body) == [concave])
        #expect(abs(hits[0].point.x + 2) < 0.000_01)
        hits = try WorldQuery.raycast(
            from: Vector(x: 1, y: 3),
            to: Vector(x: 1, y: 0.5),
            in: world
        )
        #expect(hits.isEmpty)
    }

    @Test("Compound narrow phase detects parts without filling concave gaps")
    func collisions() throws {
        var world = World()
        let compound = try world.add(
            Bodies.fromVertices(at: .zero, vertices: concaveVertices, isStatic: true)
        )
        let inside = try world.add(Bodies.circle(at: Vector(x: -1, y: 1), radius: 0.25))
        let notch = try world.add(Bodies.circle(at: Vector(x: 1, y: 1), radius: 0.25))

        let collisions = CollisionDetector.collisions(in: world)
        #expect(collisions.map(\.pair) == [try #require(BodyPair(compound, inside))])
        let compoundBody = try #require(world.body(withID: compound))
        let notchBody = try #require(world.body(withID: notch))
        #expect(
            CollisionDetector.collision(
                between: compoundBody,
                and: notchBody) == nil)

        let resolved = try CollisionSolver.resolve(
            world: &world,
            configuration: SolverConfiguration(
                velocityIterations: 1,
                positionIterations: 1,
                positionCorrection: 1
            )
        )
        #expect(resolved.count == 1)
        #expect(world.body(withID: inside)?.position != Vector(x: -1, y: 1))
    }

    @Test("Circle-only compounds participate in queries and collisions")
    func circleParts() throws {
        let firstPart = try CompoundPart(
            shape: .circle(radius: 1),
            position: Vector(x: -2, y: 0)
        )
        let secondPart = try CompoundPart(
            shape: .circle(radius: 1),
            position: Vector(x: 2, y: 0)
        )
        var world = World()
        let compound = try world.add(Bodies.compound(at: .zero, parts: [firstPart, secondPart]))
        let circle = try world.add(Bodies.circle(at: Vector(x: 2.5, y: 0), radius: 1))
        let body = try #require(world.body(withID: compound))

        #expect(body.vertices.isEmpty)
        #expect(
            body.bounds
                == Bounds(
                    minimum: Vector(x: -3, y: -1),
                    maximum: Vector(x: 3, y: 1)))
        #expect(try WorldQuery.bodies(at: Vector(x: -2, y: 0), in: world).map(\.id) == [compound])
        #expect(try WorldQuery.bodies(at: .zero, in: world).isEmpty)
        #expect(
            CollisionDetector.collisions(in: world).map(\.pair)
                == [try #require(BodyPair(compound, circle))]
        )
    }

    @Test("Compound models round-trip through Codable")
    func codable() throws {
        let definition = try Bodies.fromVertices(at: .zero, vertices: concaveVertices)
        let data = try JSONEncoder().encode(definition)
        #expect(try JSONDecoder().decode(BodyDefinition.self, from: data) == definition)

        var world = World()
        _ = try world.add(definition)
        let worldData = try JSONEncoder().encode(world)
        #expect(try JSONDecoder().decode(World.self, from: worldData) == world)
    }
}
