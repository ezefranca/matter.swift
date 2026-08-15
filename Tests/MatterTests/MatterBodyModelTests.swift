import Foundation
import Testing

@testable import Matter

@Suite("Matter body model")
struct MatterBodyModelTests {
    @Test("Every primitive exposes area, inertia, vertices, transforms, and bounds")
    func shapeGeometryAndBounds() throws {
        let circle = BodyShape.circle(radius: 2)
        #expect(abs(circle.area - 4 * .pi) < 0.000_01)
        #expect(circle.localVertices.isEmpty)
        #expect(circle.inertia(forMass: 3) == 6)

        let rectangle = BodyShape.rectangle(width: 4, height: 2)
        #expect(rectangle.area == 8)
        #expect(rectangle.localVertices.count == 4)
        #expect(abs(rectangle.inertia(forMass: 3) - 5) < 0.000_01)

        let trapezoid = BodyShape.trapezoid(width: 6, height: 4, slope: 0.5)
        #expect(trapezoid.area == 18)
        #expect(trapezoid.localVertices.count == 4)
        #expect(trapezoid.inertia(forMass: 2).isFinite)

        let polygon = BodyShape.polygon(vertices: [
            Vector(x: -1, y: -1), Vector(x: 1, y: -1),
            Vector(x: 1, y: 1), Vector(x: -1, y: 1),
        ])
        #expect(polygon.area == 4)
        #expect(abs(polygon.inertia(forMass: 6) - 4) < 0.000_01)

        var world = World()
        let circleID = try world.add(Bodies.circle(at: Vector(x: 3, y: 4), radius: 2))
        let rectangleID = try world.add(
            Bodies.rectangle(at: Vector(x: 10, y: 20), width: 6, height: 2)
        )
        try world.updateBody(withID: rectangleID) { body in
            try body.setAngle(.pi / 2)
        }
        let circleBody = try #require(world.body(withID: circleID))
        let rectangleBody = try #require(world.body(withID: rectangleID))

        #expect(circleBody.bounds.minimum == Vector(x: 1, y: 2))
        #expect(circleBody.bounds.maximum == Vector(x: 5, y: 6))
        #expect(abs(rectangleBody.bounds.width - 2) < 0.000_01)
        #expect(abs(rectangleBody.bounds.height - 6) < 0.000_01)
        #expect(rectangleBody.vertices.count == 4)
    }

    @Test("Factories validate regular polygons, convex vertices, and trapezoids")
    func shapeFactoriesAndValidation() throws {
        let regular = try Bodies.polygon(
            at: Vector(x: 2, y: 3),
            radius: 5,
            sides: 6,
            angle: 0.25,
            mass: 2
        )
        let trapezoid = try Bodies.trapezoid(
            at: .zero,
            width: 8,
            height: 4,
            slope: 0.25
        )
        let clockwise = try Bodies.vertices(
            at: .zero,
            vertices: [
                Vector(x: -1, y: -1), Vector(x: -1, y: 1),
                Vector(x: 1, y: 1), Vector(x: 1, y: -1),
            ]
        )

        #expect(regular.shape.localVertices.count == 6)
        #expect(regular.label == "Polygon")
        #expect(trapezoid.label == "Trapezoid")
        #expect(clockwise.shape.area == 4)
        #expect(BodyShape.polygon(vertices: []).area == 0)

        #expect(throws: MatterError.invalidShapeDimension) {
            try Bodies.polygon(at: .zero, radius: 0, sides: 3)
        }
        #expect(throws: MatterError.invalidShapeDimension) {
            try Bodies.polygon(at: .zero, radius: 1, sides: 2)
        }
        #expect(throws: MatterError.invalidPolygon) {
            try Bodies.vertices(at: .zero, vertices: [.zero, Vector(x: 1, y: 1)])
        }
        #expect(throws: MatterError.invalidPolygon) {
            try Bodies.vertices(
                at: .zero,
                vertices: [.zero, Vector(x: .infinity, y: 0), Vector(x: 0, y: 1)]
            )
        }
        #expect(throws: MatterError.invalidPolygon) {
            try Bodies.vertices(
                at: .zero,
                vertices: [.zero, Vector(x: 1, y: 0), Vector(x: 2, y: 0)]
            )
        }
        #expect(throws: MatterError.invalidPolygon) {
            try Bodies.vertices(
                at: .zero,
                vertices: [
                    .zero, Vector(x: 1, y: 0), Vector(x: 2, y: 0), Vector(x: 0, y: 1),
                ]
            )
        }
        #expect(throws: MatterError.nonConvexPolygon) {
            try Bodies.vertices(
                at: .zero,
                vertices: [
                    .zero, Vector(x: 2, y: 0), Vector(x: 1, y: 0.5), Vector(x: 2, y: 2),
                    Vector(x: 0, y: 2),
                ]
            )
        }
        #expect(throws: MatterError.invalidShapeDimension) {
            try Bodies.trapezoid(at: .zero, width: 2, height: 2, slope: 1)
        }
    }

    @Test("Definitions preserve material, filtering, sensor, label, and metadata")
    func bodyPropertiesAndCollisionFilters() throws {
        let material = BodyMaterial(
            restitution: 0.8,
            friction: 0.2,
            staticFriction: 0.4,
            airFriction: 0.1,
            slop: 0.01
        )
        let filter = CollisionFilter(group: 7, category: 0b10, mask: 0b101)
        let definition = try BodyDefinition(
            shape: .rectangle(width: 4, height: 2),
            position: Vector(x: 1, y: 2),
            angle: 0.3,
            velocity: Vector(x: 3, y: 4),
            angularVelocity: 0.5,
            mass: 8,
            isSensor: true,
            label: "Player",
            metadata: ["team": "blue"],
            material: material,
            collisionFilter: filter
        )
        var world = World()
        let identifier = try world.add(definition)
        let body = try #require(world.body(withID: identifier))

        #expect(body.area == 8)
        #expect(body.centerOfMass == Vector(x: 1, y: 2))
        #expect(body.density == 1)
        #expect(body.mass == 8)
        #expect(body.inverseMass == 0.125)
        #expect(body.inverseInertia > 0)
        #expect(body.isSensor)
        #expect(body.label == "Player")
        #expect(body.metadata == ["team": "blue"])
        #expect(body.material == material)
        #expect(body.restitution == 0.8)
        #expect(body.friction == 0.2)
        #expect(body.staticFriction == 0.4)
        #expect(body.airFriction == 0.1)
        #expect(body.slop == 0.01)
        #expect(body.collisionFilter == filter)
        #expect(BodyMaterial.standard.airFriction == 0)
        #expect(CollisionFilter.all.category == 1)

        #expect(filter.allowsCollision(with: CollisionFilter(group: 7, category: 8, mask: 0)))
        #expect(
            !CollisionFilter(group: -2).allowsCollision(
                with: CollisionFilter(group: -2)
            )
        )
        #expect(
            CollisionFilter(category: 0b10, mask: 0b100).allowsCollision(
                with: CollisionFilter(category: 0b100, mask: 0b10)
            )
        )
        #expect(
            !CollisionFilter(category: 0b10, mask: 0b001).allowsCollision(
                with: CollisionFilter(category: 0b100, mask: 0b10)
            )
        )
    }

    @Test("Definition validation reports every invalid property family")
    func invalidDefinitionProperties() {
        #expect(throws: MatterError.invalidVector) {
            try BodyDefinition(shape: .circle(radius: 1), position: Vector(x: .nan, y: 0))
        }
        #expect(throws: MatterError.invalidVector) {
            try BodyDefinition(
                shape: .circle(radius: 1),
                position: .zero,
                velocity: Vector(x: 0, y: .infinity)
            )
        }
        #expect(throws: MatterError.invalidAngle) {
            try BodyDefinition(shape: .circle(radius: 1), position: .zero, angle: .nan)
        }
        #expect(throws: MatterError.invalidAngle) {
            try BodyDefinition(
                shape: .circle(radius: 1),
                position: .zero,
                angularVelocity: .infinity
            )
        }
        #expect(throws: MatterError.invalidLabel) {
            try BodyDefinition(shape: .circle(radius: 1), position: .zero, label: "")
        }
        #expect(throws: MatterError.invalidLabel) {
            try BodyDefinition(shape: .circle(radius: 1), position: .zero, label: " Body")
        }
        #expect(throws: MatterError.invalidMetadata) {
            try BodyDefinition(shape: .circle(radius: 1), position: .zero, metadata: ["": "x"])
        }
        #expect(throws: MatterError.invalidMetadata) {
            try BodyDefinition(
                shape: .circle(radius: 1),
                position: .zero,
                metadata: ["key": " value"]
            )
        }
        #expect(throws: MatterError.invalidCollisionFilter) {
            try BodyDefinition(
                shape: .circle(radius: 1),
                position: .zero,
                collisionFilter: CollisionFilter(category: 0)
            )
        }

        let invalidMaterials = [
            BodyMaterial(restitution: -.infinity), BodyMaterial(restitution: 2),
            BodyMaterial(friction: -.infinity), BodyMaterial(staticFriction: -1),
            BodyMaterial(airFriction: -1), BodyMaterial(slop: -1),
        ]
        for material in invalidMaterials {
            #expect(throws: MatterError.invalidMaterial) {
                try BodyDefinition(
                    shape: .circle(radius: 1),
                    position: .zero,
                    material: material
                )
            }
        }
    }

    @Test("Forces, torque, damping, setters, and static bodies are deterministic")
    func bodyMutationAndAngularIntegration() throws {
        let definition = try BodyDefinition(
            shape: .rectangle(width: 2, height: 2),
            position: .zero,
            mass: 2,
            material: BodyMaterial(airFriction: 0.2)
        )
        var world = World()
        let identifier = try world.add(definition)
        try world.applyForce(Vector(x: 4, y: 0), at: Vector(x: 0, y: 1), to: identifier)
        try world.applyTorque(2, to: identifier)
        try ReferenceIntegrator.step(world: &world, gravity: .zero, timeStep: 0.5)
        var body = try #require(world.body(withID: identifier))

        #expect(abs(body.velocity.x - 0.9) < 0.000_01)
        #expect(abs(body.position.x - 0.45) < 0.000_01)
        #expect(abs(body.angularVelocity - (-0.675)) < 0.000_01)
        #expect(abs(body.angle - (-0.3375)) < 0.000_01)
        #expect(body.force == .zero)
        #expect(body.torque == 0)

        try body.setPosition(Vector(x: 2, y: 3))
        try body.translate(by: Vector(x: 1, y: -1))
        try body.setAngle(0.5)
        try body.rotate(by: 0.25)
        try body.setVelocity(Vector(x: 4, y: 5))
        try body.setAngularVelocity(2)
        #expect(body.position == Vector(x: 3, y: 2))
        #expect(body.angle == 0.75)
        #expect(body.velocity == Vector(x: 4, y: 5))
        #expect(body.angularVelocity == 2)

        #expect(throws: MatterError.invalidVector) { try body.setPosition(Vector(x: .nan, y: 0)) }
        #expect(throws: MatterError.invalidVector) {
            try body.translate(by: Vector(x: .infinity, y: 0))
        }
        #expect(throws: MatterError.invalidVector) { try body.setVelocity(Vector(x: 0, y: .nan)) }
        #expect(throws: MatterError.invalidAngle) { try body.setAngle(.infinity) }
        #expect(throws: MatterError.invalidAngle) { try body.rotate(by: .nan) }
        #expect(throws: MatterError.invalidAngle) { try body.setAngularVelocity(.nan) }

        var staticWorld = World()
        let staticID = try staticWorld.add(
            Bodies.rectangle(at: .zero, width: 2, height: 2, isStatic: true)
        )
        try staticWorld.applyForce(Vector(x: 1, y: 2), at: Vector(x: 1, y: 0), to: staticID)
        try staticWorld.applyTorque(3, to: staticID)
        try ReferenceIntegrator.step(world: &staticWorld, gravity: Vector(x: 0, y: 10), timeStep: 1)
        let staticBody = try #require(staticWorld.body(withID: staticID))
        #expect(staticBody.inverseInertia == 0)
        #expect(staticBody.position == .zero)
        #expect(staticBody.torque == 0)
    }

    @Test("Bounds and expanded world collection operations are value semantic")
    func boundsAndWorldOperations() throws {
        let bounds = Bounds(
            containing: [Vector(x: -2, y: 4), Vector(x: 6, y: -4), Vector(x: 1, y: 3)]
        )
        #expect(bounds.minimum == Vector(x: -2, y: -4))
        #expect(bounds.maximum == Vector(x: 6, y: 4))
        #expect(bounds.width == 8)
        #expect(bounds.height == 8)
        #expect(bounds.center == Vector(x: 2, y: 0))
        #expect(bounds.contains(.zero))
        #expect(!bounds.contains(Vector(x: 7, y: 0)))
        #expect(bounds.overlaps(Bounds(minimum: Vector(x: 6, y: 4), maximum: Vector(x: 8, y: 6))))
        #expect(
            !bounds.overlaps(Bounds(minimum: Vector(x: 7, y: 5), maximum: Vector(x: 8, y: 6)))
        )
        #expect(bounds.translated(by: Vector(x: 1, y: 2)).minimum == Vector(x: -1, y: -2))
        #expect(bounds.expanded(by: 2).width == 12)

        var world = World()
        let first = try world.add(Bodies.circle(at: .zero, radius: 1))
        let second = try world.add(Bodies.circle(at: .zero, radius: 1))
        #expect(world.bodyCount == 2)
        #expect(world.removeBody(withID: first)?.id == first)
        #expect(world.removeBody(withID: first) == nil)
        world.removeAllBodies()
        let third = try world.add(Bodies.circle(at: .zero, radius: 1))
        #expect(third.rawValue > second.rawValue)
        world.removeAllBodies(resetIdentifiers: true)
        let reset = try world.add(Bodies.circle(at: .zero, radius: 1))
        #expect(reset.rawValue == 1)
        #expect(throws: MatterError.unknownBody(BodyID(rawValue: 999))) {
            try world.updateBody(withID: BodyID(rawValue: 999)) { _ in }
        }

        #expect(Vector(x: 1, y: 2).isFinite)
        #expect(!Vector(x: .infinity, y: 2).isFinite)
        #expect(Vector(x: 1, y: 0).cross(Vector(x: 0, y: 1)) == 1)
        #expect(Vector(x: 0, y: 0).distance(to: Vector(x: 3, y: 4)) == 5)
        let rotated = Vector(x: 1, y: 0).rotated(by: .pi / 2)
        #expect(abs(rotated.x) < 0.000_01)
        #expect(abs(rotated.y - 1) < 0.000_01)
    }

    @Test("World rejects nonfinite force and torque values")
    func invalidWorldForces() throws {
        var world = World()
        let identifier = try world.add(Bodies.circle(at: .zero, radius: 1))
        #expect(throws: MatterError.invalidVector) {
            try world.applyForce(Vector(x: .nan, y: 0), to: identifier)
        }
        #expect(throws: MatterError.invalidVector) {
            try world.applyForce(.zero, at: Vector(x: .infinity, y: 0), to: identifier)
        }
        #expect(throws: MatterError.invalidAngle) {
            try world.applyTorque(.nan, to: identifier)
        }

        var corrupted = try Bodies.circle(at: .zero, radius: 1)
        corrupted.mass = 0
        #expect(throws: MatterError.invalidMass) {
            try world.add(corrupted)
        }
    }

    #if canImport(Metal)
        @Test("Engine exposes actor-isolated point force, torque, mutation, and removal")
        func engineBodyMutationSurface() async throws {
            guard MetalBackend.isAvailable else { return }
            let engine = try Engine(gravity: .zero)
            let identifier = try await engine.add(
                Bodies.rectangle(at: .zero, width: 2, height: 2)
            )

            try await engine.applyForce(Vector(x: 2, y: 0), at: Vector(x: 0, y: 1), to: identifier)
            try await engine.applyTorque(1, to: identifier)
            try await engine.updateBody(withID: identifier) { body in
                try body.setPosition(Vector(x: 4, y: 5))
            }

            let snapshot = await engine.snapshot()
            #expect(snapshot.body(withID: identifier)?.position == Vector(x: 4, y: 5))
            #expect(await engine.removeBody(withID: identifier)?.id == identifier)
            #expect(await engine.removeBody(withID: identifier) == nil)
        }

        @Test("Metal angular integration matches the CPU reference")
        func metalAngularConformance() async throws {
            guard MetalBackend.isAvailable else { return }
            var world = World()
            let identifier = try world.add(
                try BodyDefinition(
                    shape: .rectangle(width: 3, height: 2),
                    position: .zero,
                    mass: 2,
                    material: BodyMaterial(airFriction: 0.15)
                )
            )
            try world.applyForce(Vector(x: 3, y: 2), at: Vector(x: 0, y: 2), to: identifier)
            try world.applyTorque(1, to: identifier)
            var expected = world
            try ReferenceIntegrator.step(
                world: &expected, gravity: Vector(x: 0, y: 9), timeStep: 0.1)

            let output = try await MetalBackend().integrate(
                bodies: world.bodies,
                gravity: Vector(x: 0, y: 9),
                timeStep: 0.1
            )
            let actual = try #require(output.first)
            let reference = try #require(expected.bodies.first)
            #expect(abs(actual.position.x - reference.position.x) < 0.000_01)
            #expect(abs(actual.position.y - reference.position.y) < 0.000_01)
            #expect(abs(actual.angle - reference.angle) < 0.000_01)
            #expect(abs(actual.angularVelocity - reference.angularVelocity) < 0.000_01)
            #expect(actual.force == .zero)
            #expect(actual.torque == 0)
        }
    #endif
}
