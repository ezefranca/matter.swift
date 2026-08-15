import Foundation
import Testing

@testable import Matter

@Suite("Matter persistent contacts and warm starting")
struct MatterWarmStartingTests {
    @Test("Contact features remain stable across detection and identify compound parts")
    func featureIdentity() throws {
        let left = try CompoundPart(
            shape: .circle(radius: 1),
            position: Vector(x: -2, y: 0)
        )
        let right = try CompoundPart(
            shape: .circle(radius: 1),
            position: Vector(x: 2, y: 0)
        )
        var world = World()
        let compound = try world.add(Bodies.compound(at: .zero, parts: [left, right]))
        let circle = try world.add(Bodies.circle(at: Vector(x: 2.5, y: 0), radius: 1))
        let first = try #require(CollisionDetector.collisions(in: world).first)
        let second = try #require(CollisionDetector.collisions(in: world).first)
        let reversed = CollisionDetector.collision(
            between: try #require(world.body(withID: circle)),
            and: try #require(world.body(withID: compound))
        )
        let feature = try #require(first.contacts.first).featureID

        #expect(reversed == first)
        #expect(first.contacts.map(\.featureID) == second.contacts.map(\.featureID))
        #expect(feature.firstPart == 1)
        #expect(feature.secondPart == 0)
        #expect(feature.contact == 0)

        let pair = try #require(BodyPair(compound, circle))
        let key = ContactKey(pair: pair, featureID: feature)
        #expect(key.pair == pair)
        #expect(key.featureID == feature)
        #expect(!(key < key))

        let otherFeature = ContactFeatureID(firstPart: 1, secondPart: 1, contact: 0)
        let otherKey = ContactKey(pair: pair, featureID: otherFeature)
        #expect(feature < otherFeature)
        #expect(key < otherKey)
        #expect(ContactFeatureID(firstPart: 0, secondPart: 9, contact: 9) < feature)
        #expect(
            ContactFeatureID(firstPart: 1, secondPart: 0, contact: 0)
                < ContactFeatureID(firstPart: 1, secondPart: 0, contact: 1))
    }

    @Test("State persists accumulated impulses and prunes ended contacts")
    func cacheLifecycle() throws {
        var world = World()
        let material = BodyMaterial(restitution: 0, friction: 0.5, staticFriction: 1, slop: 0)
        let ground = try world.add(
            BodyDefinition(
                shape: .rectangle(width: 20, height: 2),
                position: Vector(x: 0, y: 2),
                isStatic: true,
                material: material
            )
        )
        let box = try world.add(
            BodyDefinition(
                shape: .rectangle(width: 2, height: 2),
                position: Vector(x: 0, y: 0.5),
                velocity: Vector(x: 1, y: 1),
                material: material
            )
        )
        var state = CollisionSolverState()
        let collisions = try CollisionSolver.resolve(
            world: &world,
            state: &state,
            configuration: SolverConfiguration(
                velocityIterations: 4,
                positionIterations: 1,
                positionCorrection: 0
            )
        )
        let collision = try #require(collisions.first)

        #expect(collision.pair == BodyPair(ground, box))
        #expect(state.contactCount > 0)
        #expect(state.activeContacts == state.activeContacts.sorted())
        let key = try #require(state.activeContacts.first)
        let impulse = try #require(state.impulse(for: key))
        #expect(impulse.normal > 0)
        #expect(impulse.tangent != 0)

        let encoded = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(CollisionSolverState.self, from: encoded) == state)

        try world.updateBody(withID: box) { body in
            try body.setPosition(Vector(x: 100, y: 100))
        }
        #expect(try CollisionSolver.resolve(world: &world, state: &state).isEmpty)
        #expect(state.contactCount == 0)
        #expect(state.impulse(for: key) == nil)

        state.reset()
        #expect(state.activeContacts.isEmpty)
    }

    @Test("Warm starting preserves a low-iteration resting stack")
    func stackingStability() throws {
        var world = World()
        let material = BodyMaterial(
            restitution: 0,
            friction: 0.4,
            staticFriction: 0.8,
            airFriction: 0,
            slop: 0.01
        )
        _ = try world.add(
            BodyDefinition(
                shape: .rectangle(width: 20, height: 2),
                position: Vector(x: 0, y: 6),
                isStatic: true,
                material: material
            )
        )
        let boxes = try world.add(
            (0..<4).map { index in
                try BodyDefinition(
                    shape: .rectangle(width: 2, height: 2),
                    position: Vector(x: 0, y: 4 - Float(index) * 2),
                    material: material
                )
            }
        )
        var state = CollisionSolverState()
        let configuration = SolverConfiguration(
            velocityIterations: 2,
            positionIterations: 2,
            positionCorrection: 0.8,
            restitutionVelocityThreshold: 1
        )

        for _ in 0..<240 {
            try ReferenceIntegrator.step(
                world: &world,
                gravity: Vector(x: 0, y: 9.81),
                timeStep: 1 / 60
            )
            try CollisionSolver.resolve(
                world: &world,
                state: &state,
                configuration: configuration
            )
        }

        let dynamicBodies = boxes.compactMap(world.body(withID:))
        #expect(dynamicBodies.count == boxes.count)
        #expect(dynamicBodies.allSatisfy { abs($0.position.x) < 0.05 })
        #expect(dynamicBodies.allSatisfy { abs($0.velocity.y) < 0.2 })
        #expect(dynamicBodies.allSatisfy { abs($0.angularVelocity) < 0.2 })
        #expect(state.contactCount >= boxes.count)
    }

    @Test("State ordering and impulse values round-trip independently")
    func valueSemantics() throws {
        let firstPair = try #require(BodyPair(BodyID(rawValue: 1), BodyID(rawValue: 2)))
        let secondPair = try #require(BodyPair(BodyID(rawValue: 2), BodyID(rawValue: 3)))
        let firstFeature = ContactFeatureID(firstPart: 0, secondPart: 0, contact: 0)
        let secondFeature = ContactFeatureID(firstPart: 0, secondPart: 0, contact: 1)
        let firstKey = ContactKey(pair: firstPair, featureID: firstFeature)
        let secondKey = ContactKey(pair: secondPair, featureID: secondFeature)

        #expect(firstKey < secondKey)
        let impulse = ContactImpulse(normal: 2, tangent: -0.5)
        #expect(impulse.normal == 2)
        #expect(impulse.tangent == -0.5)
        let data = try JSONEncoder().encode(impulse)
        #expect(try JSONDecoder().decode(ContactImpulse.self, from: data) == impulse)
    }

    #if canImport(Metal)
        @Test("Engine owns and resets its warm-start cache")
        func engineState() async throws {
            guard MetalBackend.isAvailable else { return }
            let engine = try Engine(gravity: Vector(x: 0, y: 10), fixedTimeStep: 0.1)
            _ = try await engine.add(
                Bodies.rectangle(at: Vector(x: 0, y: 2), width: 20, height: 2, isStatic: true)
            )
            _ = try await engine.add(Bodies.circle(at: Vector(x: 0, y: 0.5), radius: 1))

            _ = try await engine.step()
            #expect(await engine.solverStateSnapshot().contactCount > 0)
            await engine.reset()
            #expect(await engine.solverStateSnapshot().contactCount == 0)
        }
    #endif
}
