import Foundation
import Testing

@testable import Matter

@Suite("Matter force behaviors")
struct MatterAttractionTests {
    @Test("Attractors validate every source and tuning family")
    func validation() throws {
        #expect(throws: MatterError.invalidForceBehavior) {
            try Attractor(source: .point(position: Vector(x: .nan, y: 0), mass: 1))
        }
        #expect(throws: MatterError.invalidForceBehavior) {
            try Attractor(source: .point(position: .zero, mass: 0))
        }
        #expect(throws: MatterError.invalidForceBehavior) {
            try Attractor(source: .point(position: .zero, mass: .infinity))
        }
        for values in [
            (Float.nan, Float(1), Float(2), Optional<Float>.none),
            (Float(1), Float(0), Float(2), Optional<Float>.none),
            (Float(1), Float.infinity, Float(2), Optional<Float>.none),
            (Float(1), Float(3), Float(2), Optional<Float>.none),
            (Float(1), Float(1), Float.infinity, Optional<Float>.none),
            (Float(1), Float(1), Float(2), Optional<Float>.some(0)),
            (Float(1), Float(1), Float(2), Optional<Float>.some(.nan)),
        ] {
            #expect(throws: MatterError.invalidForceBehavior) {
                try Attractor(
                    source: .point(position: .zero, mass: 1),
                    strength: values.0,
                    minimumDistance: values.1,
                    maximumDistance: values.2,
                    maximumForce: values.3
                )
            }
        }
        #expect(throws: MatterError.invalidCollisionFilter) {
            try Attractor(
                source: .body(BodyID(rawValue: 1)),
                targetFilter: CollisionFilter(category: 0)
            )
        }

        var corrupted = try Attractor(source: .point(position: .zero, mass: 1))
        corrupted.maximumDistance = -1
        #expect(throws: MatterError.invalidForceBehavior) {
            try corrupted.applications(in: World())
        }
    }

    @Test("Inverse-square forces clamp distance and preserve signed direction")
    func forceCalculation() throws {
        var world = World()
        let near = try world.add(Bodies.circle(at: Vector(x: 1, y: 0), radius: 0.25, mass: 3))
        let far = try world.add(Bodies.circle(at: Vector(x: 100, y: 0), radius: 0.25, mass: 2))
        let field = try Attractor(
            source: .point(position: .zero, mass: 2),
            strength: 4,
            minimumDistance: 2,
            maximumDistance: 10
        )

        #expect(
            try field.force(on: #require(world.body(withID: near)), in: world)
                == Vector(x: -6, y: 0))
        #expect(
            try field.force(on: #require(world.body(withID: far)), in: world)
                == Vector(x: -0.16, y: 0)
        )

        let repeller = try Attractor(
            source: .point(position: .zero, mass: 10),
            strength: -10,
            minimumDistance: 1,
            maximumDistance: 10,
            maximumForce: 2
        )
        #expect(
            try repeller.force(on: #require(world.body(withID: near)), in: world)
                == Vector(x: 2, y: 0)
        )

        let cappedAttractor = try Attractor(
            source: .point(position: .zero, mass: 10),
            strength: 10,
            minimumDistance: 1,
            maximumDistance: 10,
            maximumForce: 2
        )
        #expect(
            try cappedAttractor.force(on: #require(world.body(withID: near)), in: world)
                == Vector(x: -2, y: 0)
        )
    }

    @Test("Body sources, filtering, and immovable cases produce stable applications")
    func sourceAndFiltering() throws {
        var world = World()
        let source = try world.add(Bodies.circle(at: .zero, radius: 1, mass: 5))
        let included = try world.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: 5, y: 0),
                mass: 2,
                collisionFilter: CollisionFilter(category: 2, mask: 1)
            )
        )
        let filtered = try world.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: 6, y: 0),
                collisionFilter: CollisionFilter(category: 4, mask: 4)
            )
        )
        let fixed = try world.add(Bodies.circle(at: Vector(x: 7, y: 0), radius: 1, isStatic: true))
        let coincident = try world.add(Bodies.circle(at: .zero, radius: 0.5))
        let field = try Attractor(
            source: .body(source),
            strength: 1,
            minimumDistance: 1,
            maximumDistance: 100,
            targetFilter: CollisionFilter(category: 1, mask: 2)
        )

        let applications = try field.applications(in: world)
        #expect(applications.map(\.body) == [included])
        #expect(applications.first?.force == Vector(x: -0.4, y: 0))
        #expect(try field.force(on: #require(world.body(withID: source)), in: world) == .zero)
        #expect(try field.force(on: #require(world.body(withID: filtered)), in: world) == .zero)
        #expect(try field.force(on: #require(world.body(withID: fixed)), in: world) == .zero)
        let unfiltered = try Attractor(
            source: .body(source),
            minimumDistance: 1,
            maximumDistance: 100
        )
        #expect(
            try unfiltered.force(on: #require(world.body(withID: coincident)), in: world) == .zero)
    }

    @Test("Explicit targets preserve order and validate the entire batch")
    func explicitTargets() throws {
        var world = World()
        let first = try world.add(Bodies.circle(at: Vector(x: 2, y: 0), radius: 1))
        let second = try world.add(Bodies.circle(at: Vector(x: 4, y: 0), radius: 1))
        let field = try Attractor(
            source: .point(position: .zero, mass: 1),
            minimumDistance: 1,
            maximumDistance: 10
        )

        #expect(try field.applications(to: [], in: world).isEmpty)
        #expect(
            try field.applications(to: [second, first], in: world).map(\.body) == [second, first])
        #expect(throws: MatterError.duplicateBody(first)) {
            try field.applications(to: [first, first], in: world)
        }
        let missing = BodyID(rawValue: 999)
        #expect(throws: MatterError.unknownBody(missing)) {
            try field.applications(to: [first, missing], in: world)
        }

        let before = world
        #expect(throws: MatterError.unknownBody(missing)) {
            try field.apply(to: [first, missing], in: &world)
        }
        #expect(world == before)
    }

    @Test("Applying fields accumulates forces and returns inspectable values")
    func apply() throws {
        var world = World()
        let first = try world.add(Bodies.circle(at: Vector(x: 3, y: 4), radius: 1, mass: 2))
        let second = try world.add(Bodies.circle(at: Vector(x: -3, y: -4), radius: 1))
        let field = try Attractor(
            source: .point(position: .zero, mass: 5),
            strength: 2,
            minimumDistance: 1,
            maximumDistance: 10
        )
        let applications = try field.apply(to: [first, second], in: &world)

        #expect(applications.map(\.body) == [first, second])
        #expect(world.body(withID: first)?.force == applications[0].force)
        #expect(world.body(withID: second)?.force == applications[1].force)

        let disabled = try Attractor(
            source: .point(position: .zero, mass: 1),
            strength: 0
        )
        #expect(try disabled.apply(in: &world).isEmpty)
    }

    @Test("Missing body sources fail before target mutation")
    func missingSource() throws {
        var world = World()
        let target = try world.add(Bodies.circle(at: Vector(x: 2, y: 0), radius: 1))
        let missing = BodyID(rawValue: 404)
        let field = try Attractor(source: .body(missing))
        let body = try #require(world.body(withID: target))

        #expect(throws: MatterError.unknownBody(missing)) {
            try field.force(on: body, in: world)
        }
        #expect(throws: MatterError.unknownBody(missing)) {
            try field.apply(in: &world)
        }
        #expect(world.body(withID: target)?.force == .zero)
    }

    @Test("Force behavior values round-trip through Codable")
    func codable() throws {
        let point = try Attractor(
            source: .point(position: Vector(x: 1, y: 2), mass: 3),
            strength: -4,
            minimumDistance: 2,
            maximumDistance: 20,
            maximumForce: 8,
            targetFilter: CollisionFilter(group: -1, category: 2, mask: 4)
        )
        let body = try Attractor(source: .body(BodyID(rawValue: 7)))
        for value in [point, body] {
            let data = try JSONEncoder().encode(value)
            #expect(try JSONDecoder().decode(Attractor.self, from: data) == value)
        }

        let application = ForceApplication(
            body: BodyID(rawValue: 9),
            force: Vector(x: 1, y: -2)
        )
        let data = try JSONEncoder().encode(application)
        #expect(try JSONDecoder().decode(ForceApplication.self, from: data) == application)
    }

    #if canImport(Metal)
        @Test("Engine accumulates attraction before its next Metal tick")
        func engineApply() async throws {
            guard MetalBackend.isAvailable else { return }
            let engine = try Engine(gravity: .zero)
            let body = try await engine.add(Bodies.circle(at: Vector(x: 2, y: 0), radius: 1))
            let field = try Attractor(
                source: .point(position: .zero, mass: 1),
                minimumDistance: 1,
                maximumDistance: 10
            )

            #expect(
                try await engine.apply(field) == [
                    ForceApplication(body: body, force: Vector(x: -0.25, y: 0))
                ])
            #expect(await engine.snapshot().body(withID: body)?.force == Vector(x: -0.25, y: 0))
        }
    #endif
}
