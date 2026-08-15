import Foundation
import Testing

@testable import Matter

@Suite("Matter constraints")
struct MatterConstraintTests {
    @Test("Constraint identifiers, definitions, and factories preserve configuration")
    func modelAndFactories() throws {
        let first = BodyID(rawValue: 1)
        let second = BodyID(rawValue: 2)
        let pin = try Constraints.pin(
            first,
            localAnchor: Vector(x: 1, y: 0),
            to: Vector(x: 4, y: 5),
            length: 3,
            stiffness: 0.8,
            damping: 0.2,
            angularStiffness: 0.3,
            maximumImpulse: 10
        )
        #expect(pin.first == .fixed(Vector(x: 4, y: 5)))
        #expect(pin.second == .body(first, local: Vector(x: 1, y: 0)))
        #expect(pin.length == 3)
        #expect(pin.stiffness == 0.8)
        #expect(pin.damping == 0.2)
        #expect(pin.angularStiffness == 0.3)
        #expect(pin.maximumImpulse == 10)
        #expect(pin.label == "Pin")

        let distance = try Constraints.distance(
            between: first,
            localAnchor: Vector(x: 1, y: 2),
            and: second,
            localAnchor: Vector(x: 3, y: 4)
        )
        #expect(distance.first == .body(first, local: Vector(x: 1, y: 2)))
        #expect(distance.second == .body(second, local: Vector(x: 3, y: 4)))
        #expect(distance.label == "Distance")

        let spring = try Constraints.spring(between: first, and: second)
        #expect(spring.stiffness == 0.2)
        #expect(spring.damping == 0.1)
        let lower = ConstraintID(rawValue: 1)
        let upper = ConstraintID(rawValue: 2)
        #expect(lower < upper)
        #expect(ConstraintID(rawValue: lower.rawValue) == lower)
    }

    @Test("Constraint definitions reject every invalid value family")
    func definitionValidation() throws {
        let body = BodyID(rawValue: 1)
        #expect(throws: MatterError.invalidConstraint) {
            try ConstraintDefinition(first: .fixed(.zero), second: .fixed(Vector(x: 1, y: 0)))
        }
        #expect(throws: MatterError.invalidConstraint) {
            try ConstraintDefinition(first: .body(body), second: .body(body))
        }
        #expect(throws: MatterError.invalidVector) {
            try ConstraintDefinition(
                first: .fixed(Vector(x: .nan, y: 0)),
                second: .body(body)
            )
        }
        #expect(throws: MatterError.invalidVector) {
            try ConstraintDefinition(
                first: .fixed(.zero),
                second: .body(body, local: Vector(x: 0, y: .infinity))
            )
        }

        let invalidDefinitions: [() throws -> ConstraintDefinition] = [
            { try ConstraintDefinition(first: .fixed(.zero), second: .body(body), length: -1) },
            {
                try ConstraintDefinition(
                    first: .fixed(.zero), second: .body(body), length: .nan)
            },
            {
                try ConstraintDefinition(
                    first: .fixed(.zero), second: .body(body), stiffness: -0.1)
            },
            {
                try ConstraintDefinition(
                    first: .fixed(.zero), second: .body(body), stiffness: .infinity)
            },
            {
                try ConstraintDefinition(
                    first: .fixed(.zero), second: .body(body), damping: 1.1)
            },
            {
                try ConstraintDefinition(
                    first: .fixed(.zero), second: .body(body), damping: .nan)
            },
            {
                try ConstraintDefinition(
                    first: .fixed(.zero), second: .body(body), angularStiffness: -1)
            },
            {
                try ConstraintDefinition(
                    first: .fixed(.zero), second: .body(body), angularStiffness: .infinity)
            },
            {
                try ConstraintDefinition(
                    first: .fixed(.zero), second: .body(body), maximumImpulse: 0)
            },
            {
                try ConstraintDefinition(
                    first: .fixed(.zero), second: .body(body), maximumImpulse: .infinity)
            },
        ]
        for definition in invalidDefinitions {
            #expect(throws: MatterError.invalidConstraint) { try definition() }
        }
        #expect(throws: MatterError.invalidLabel) {
            try ConstraintDefinition(first: .fixed(.zero), second: .body(body), label: " bad")
        }
        #expect(throws: MatterError.invalidMetadata) {
            try ConstraintDefinition(
                first: .fixed(.zero),
                second: .body(body),
                metadata: ["key": " bad"]
            )
        }
    }

    @Test("World captures rest state and composites organize constraints")
    func worldAndCompositeMembership() throws {
        var world = World()
        let root = try world.addComposite(label: "Root")
        let child = try world.addComposite(label: "Child", parent: root)
        let first = try world.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: 3, y: 4),
                angle: 0.25
            )
        )
        let second = try world.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: 8, y: 4),
                angle: 0.75
            )
        )
        let pin = try world.addConstraint(Constraints.pin(first, to: .zero), to: root)
        let distance = try world.addConstraint(
            Constraints.distance(between: first, and: second),
            to: child
        )

        #expect(world.constraintCount == 2)
        #expect(world.constraint(withID: pin)?.length == 5)
        #expect(world.constraint(withID: pin)?.referenceAngle == 0.25)
        #expect(world.constraint(withID: distance)?.length == 5)
        #expect(world.constraint(withID: distance)?.referenceAngle == 0.5)
        #expect(world.constraint(withID: pin)?.references(first) == true)
        #expect(world.constraint(withID: distance)?.references(second) == true)
        #expect(world.constraint(withID: pin)?.references(second) == false)
        #expect(world.composite(containing: pin)?.id == root)
        #expect(world.composite(withID: child)?.constraintIDs == [distance])
        #expect(try world.constraints(in: root).map(\.id) == [pin, distance])
        #expect(
            try world.constraints(in: root, includingDescendants: false).map(\.id) == [pin]
        )

        try world.assignConstraint(pin, to: child)
        try world.assignConstraint(pin, to: child)
        #expect(world.composite(withID: root)?.constraintIDs.isEmpty == true)
        #expect(world.composite(withID: child)?.constraintIDs == [distance, pin])
        #expect(try world.unassignConstraint(pin) == child)
        #expect(try world.unassignConstraint(pin) == nil)
        #expect(world.composite(containing: pin) == nil)
    }

    @Test("Constraint world mutations clean dependencies and report unknown values")
    func worldMutationAndValidation() throws {
        var world = World()
        let composite = try world.addComposite()
        let first = try world.add(Bodies.circle(at: .zero, radius: 1))
        let second = try world.add(Bodies.circle(at: Vector(x: 2, y: 0), radius: 1))
        let missingBody = BodyID(rawValue: 999)
        let missingComposite = CompositeID(rawValue: 999)
        let missingConstraint = ConstraintID(rawValue: 999)

        #expect(throws: MatterError.unknownBody(missingBody)) {
            try world.addConstraint(Constraints.pin(missingBody, to: .zero))
        }
        #expect(throws: MatterError.unknownBody(missingBody)) {
            try world.addConstraint(
                ConstraintDefinition(first: .body(first), second: .body(missingBody))
            )
        }
        #expect(throws: MatterError.unknownComposite(missingComposite)) {
            try world.addConstraint(Constraints.pin(first, to: .zero), to: missingComposite)
        }
        let constraint = try world.addConstraint(
            Constraints.distance(between: first, and: second),
            to: composite
        )
        #expect(throws: MatterError.unknownConstraint(missingConstraint)) {
            try world.assignConstraint(missingConstraint, to: composite)
        }
        #expect(throws: MatterError.unknownComposite(missingComposite)) {
            try world.assignConstraint(constraint, to: missingComposite)
        }
        #expect(throws: MatterError.unknownConstraint(missingConstraint)) {
            try world.unassignConstraint(missingConstraint)
        }
        #expect(world.removeConstraint(withID: missingConstraint) == nil)
        #expect(world.removeConstraint(withID: constraint)?.id == constraint)
        #expect(world.composite(withID: composite)?.constraintIDs.isEmpty == true)

        let pin = try world.addConstraint(Constraints.pin(first, to: .zero), to: composite)
        _ = try world.addConstraint(Constraints.pin(second, to: .zero), to: composite)
        #expect(world.removeBody(withID: first)?.id == first)
        #expect(world.constraint(withID: pin) == nil)
        #expect(world.constraintCount == 1)
        _ = try world.removeBodies(withIDs: [second])
        #expect(world.constraints.isEmpty)
        #expect(world.composite(withID: composite)?.constraintIDs.isEmpty == true)
    }

    @Test("Constraint clearing and composite removal have explicit ownership semantics")
    func removalSemantics() throws {
        var world = World()
        let root = try world.addComposite()
        let child = try world.addComposite(parent: root)
        let first = try world.add(Bodies.circle(at: .zero, radius: 1))
        let second = try world.add(Bodies.circle(at: Vector(x: 2, y: 0), radius: 1))
        let retained = try world.addConstraint(
            Constraints.distance(between: first, and: second),
            to: child
        )

        _ = try world.removeComposite(withID: root)
        #expect(world.constraint(withID: retained) != nil)
        #expect(world.composite(containing: retained) == nil)

        let removing = try world.addComposite()
        try world.assignConstraint(retained, to: removing)
        _ = try world.removeComposite(withID: removing, removeConstraints: true)
        #expect(world.constraints.isEmpty)

        let next = try world.addConstraint(Constraints.pin(first, to: .zero))
        world.removeAllConstraints()
        let monotonic = try world.addConstraint(Constraints.pin(first, to: .zero))
        #expect(monotonic.rawValue > next.rawValue)
        world.removeAllConstraints(resetIdentifiers: true)
        #expect(try world.addConstraint(Constraints.pin(first, to: .zero)).rawValue == 1)

        let bodyGroup = try world.addComposite()
        try world.assignBody(first, to: bodyGroup)
        _ = try world.addConstraint(Constraints.pin(first, to: .zero), to: bodyGroup)
        world.removeAllComposites(removeBodies: true, removeConstraints: true)
        #expect(world.body(withID: first) == nil)
        #expect(world.constraints.isEmpty)
        #expect(world.body(withID: second) != nil)

        let finalGroup = try world.addComposite()
        let finalConstraint = try world.addConstraint(
            Constraints.pin(second, to: .zero), to: finalGroup)
        world.removeAllComposites(removeConstraints: true)
        #expect(world.constraint(withID: finalConstraint) == nil)
        world.removeAllBodies()
        #expect(world.constraints.isEmpty)
    }

    @Test("Position solving enforces pin, distance, coincident, and static anchors")
    func positionSolving() throws {
        var pinWorld = World()
        let pinned = try pinWorld.add(Bodies.circle(at: Vector(x: 10, y: 0), radius: 1))
        _ = try pinWorld.addConstraint(
            Constraints.pin(pinned, to: .zero, length: 5, stiffness: 1)
        )
        #expect(
            try ConstraintSolver.resolve(
                world: &pinWorld,
                timeStep: 1,
                configuration: ConstraintSolverConfiguration(
                    velocityIterations: 1,
                    positionIterations: 1
                )
            ).isEmpty
        )
        #expect(pinWorld.body(withID: pinned)?.position == Vector(x: 5, y: 0))

        var pairWorld = World()
        let first = try pairWorld.add(Bodies.circle(at: .zero, radius: 1))
        let second = try pairWorld.add(Bodies.circle(at: Vector(x: 10, y: 0), radius: 1))
        _ = try pairWorld.addConstraint(
            Constraints.distance(between: first, and: second, length: 4)
        )
        try ConstraintSolver.resolve(
            world: &pairWorld,
            timeStep: 1,
            configuration: ConstraintSolverConfiguration(
                velocityIterations: 1,
                positionIterations: 1
            )
        )
        #expect(pairWorld.body(withID: first)?.position == Vector(x: 3, y: 0))
        #expect(pairWorld.body(withID: second)?.position == Vector(x: 7, y: 0))

        var coincidentWorld = World()
        let coincidentA = try coincidentWorld.add(Bodies.circle(at: .zero, radius: 1))
        let coincidentB = try coincidentWorld.add(Bodies.circle(at: .zero, radius: 1))
        _ = try coincidentWorld.addConstraint(
            Constraints.distance(between: coincidentA, and: coincidentB, length: 2)
        )
        try ConstraintSolver.resolve(
            world: &coincidentWorld,
            timeStep: 1,
            configuration: ConstraintSolverConfiguration(
                velocityIterations: 1,
                positionIterations: 1
            )
        )
        #expect(coincidentWorld.body(withID: coincidentA)?.position == Vector(x: -1, y: 0))
        #expect(coincidentWorld.body(withID: coincidentB)?.position == Vector(x: 1, y: 0))

        var staticWorld = World()
        let fixed = try staticWorld.add(
            Bodies.circle(at: Vector(x: 10, y: 0), radius: 1, isStatic: true)
        )
        _ = try staticWorld.addConstraint(Constraints.pin(fixed, to: .zero, length: 0))
        try ConstraintSolver.resolve(world: &staticWorld, timeStep: 1)
        #expect(staticWorld.body(withID: fixed)?.position == Vector(x: 10, y: 0))

        let dynamic = try staticWorld.add(
            Bodies.circle(at: Vector(x: 20, y: 0), radius: 1, velocity: Vector(x: 1, y: 0))
        )
        _ = try staticWorld.addConstraint(
            Constraints.distance(
                between: fixed,
                and: dynamic,
                length: 4,
                damping: 1,
                angularStiffness: 1
            )
        )
        try staticWorld.updateBody(withID: dynamic) { body in
            try body.setAngle(1)
            try body.setAngularVelocity(1)
        }
        try ConstraintSolver.resolve(
            world: &staticWorld,
            timeStep: 1,
            configuration: ConstraintSolverConfiguration(
                velocityIterations: 1,
                positionIterations: 1
            )
        )
        #expect(staticWorld.body(withID: fixed)?.position == Vector(x: 10, y: 0))
        #expect(staticWorld.body(withID: fixed)?.angle == 0)
        #expect(staticWorld.body(withID: dynamic)?.position == Vector(x: 14, y: 0))
        #expect(abs(try #require(staticWorld.body(withID: dynamic)).angle) < 0.000_01)
    }

    @Test("Damping and off-center anchors change linear and angular motion")
    func dampingAndAngularImpulse() throws {
        var world = World()
        let first = try world.add(
            Bodies.circle(at: .zero, radius: 1, velocity: Vector(x: -1, y: 0))
        )
        let second = try world.add(
            Bodies.circle(at: Vector(x: 10, y: 0), radius: 1, velocity: Vector(x: 1, y: 0))
        )
        _ = try world.addConstraint(
            Constraints.distance(
                between: first,
                localAnchor: Vector(x: 0, y: 1),
                and: second,
                localAnchor: Vector(x: 0, y: 1),
                length: 8,
                stiffness: 1,
                damping: 1
            )
        )
        try ConstraintSolver.resolve(
            world: &world,
            timeStep: 1,
            configuration: ConstraintSolverConfiguration(
                velocityIterations: 1,
                positionIterations: 1
            )
        )
        let firstResult = try #require(world.body(withID: first))
        let secondResult = try #require(world.body(withID: second))
        #expect(abs(firstResult.velocity.x) < 1)
        #expect(abs(secondResult.velocity.x) < 1)
        #expect(firstResult.angle != 0)
        #expect(secondResult.angle != 0)

        var pinWorld = World()
        let body = try pinWorld.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: 2, y: 0),
                velocity: Vector(x: 2, y: 0),
                angularVelocity: 2
            )
        )
        _ = try pinWorld.addConstraint(
            Constraints.pin(body, to: .zero, length: 2, stiffness: 0, damping: 1)
        )
        try ConstraintSolver.resolve(
            world: &pinWorld,
            timeStep: 1,
            configuration: ConstraintSolverConfiguration(
                velocityIterations: 1,
                positionIterations: 1
            )
        )
        #expect(abs(try #require(pinWorld.body(withID: body)).velocity.x) < 0.000_01)
        #expect(abs(try #require(pinWorld.body(withID: body)).angularVelocity) < 0.000_01)

        var reverseWorld = World()
        let reverseBody = try reverseWorld.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: 2, y: 0),
                velocity: Vector(x: -2, y: 0),
                angularVelocity: -2
            )
        )
        _ = try reverseWorld.addConstraint(
            ConstraintDefinition(
                first: .body(reverseBody),
                second: .fixed(.zero),
                length: 2,
                stiffness: 0,
                damping: 1
            )
        )
        try ConstraintSolver.resolve(
            world: &reverseWorld,
            timeStep: 1,
            configuration: ConstraintSolverConfiguration(
                velocityIterations: 1,
                positionIterations: 1
            )
        )
        #expect(abs(try #require(reverseWorld.body(withID: reverseBody)).velocity.x) < 0.000_01)
    }

    @Test("Angular stiffness preserves captured single-body and relative angles")
    func angularStiffness() throws {
        var pinWorld = World()
        let pinned = try pinWorld.add(Bodies.rectangle(at: .zero, width: 2, height: 1))
        _ = try pinWorld.addConstraint(
            Constraints.pin(pinned, to: .zero, angularStiffness: 1)
        )
        try pinWorld.updateBody(withID: pinned) { try $0.setAngle(.pi / 2) }
        try ConstraintSolver.resolve(
            world: &pinWorld,
            timeStep: 1,
            configuration: ConstraintSolverConfiguration(
                velocityIterations: 1,
                positionIterations: 1
            )
        )
        #expect(abs(try #require(pinWorld.body(withID: pinned)).angle) < 0.000_01)

        var pairWorld = World()
        let first = try pairWorld.add(Bodies.rectangle(at: .zero, width: 2, height: 1))
        let second = try pairWorld.add(
            Bodies.rectangle(at: Vector(x: 4, y: 0), width: 2, height: 1)
        )
        _ = try pairWorld.addConstraint(
            Constraints.distance(
                between: first,
                and: second,
                angularStiffness: 1
            )
        )
        try pairWorld.updateBody(withID: first) { try $0.setAngle(-0.5) }
        try pairWorld.updateBody(withID: second) { try $0.setAngle(0.5) }
        try ConstraintSolver.resolve(
            world: &pairWorld,
            timeStep: 1,
            configuration: ConstraintSolverConfiguration(
                velocityIterations: 1,
                positionIterations: 1
            )
        )
        let firstBody = try #require(pairWorld.body(withID: first))
        let secondBody = try #require(pairWorld.body(withID: second))
        #expect(abs(secondBody.angle - firstBody.angle) < 0.000_01)
    }

    @Test("Break limits remove constraints before applying excessive correction")
    func breakLimits() throws {
        var world = World()
        let composite = try world.addComposite()
        let body = try world.add(Bodies.circle(at: Vector(x: 10, y: 0), radius: 1))
        let breaking = try world.addConstraint(
            Constraints.pin(
                body,
                to: .zero,
                length: 0,
                stiffness: 1,
                maximumImpulse: 1
            ),
            to: composite
        )
        let broken = try ConstraintSolver.resolve(world: &world, timeStep: 1)
        #expect(broken == [breaking])
        #expect(world.constraints.isEmpty)
        #expect(world.composite(withID: composite)?.constraintIDs.isEmpty == true)
        #expect(world.body(withID: body)?.position == Vector(x: 10, y: 0))

        let angular = try world.addConstraint(
            Constraints.pin(
                body,
                to: Vector(x: 10, y: 0),
                stiffness: 0,
                angularStiffness: 1,
                maximumImpulse: 0.1
            )
        )
        try world.updateBody(withID: body) { try $0.setAngle(.pi / 2) }
        #expect(try ConstraintSolver.resolve(world: &world, timeStep: 1) == [angular])
    }

    @Test("Solver validates configuration, time, and externally corrupted references")
    func solverValidation() throws {
        #expect(ConstraintSolverConfiguration.standard.velocityIterations == 2)
        #expect(ConstraintSolverConfiguration.standard.positionIterations == 4)
        var world = World()
        #expect(throws: MatterError.invalidTimeStep) {
            try ConstraintSolver.resolve(world: &world, timeStep: 0)
        }
        #expect(throws: MatterError.invalidConstraintSolverConfiguration) {
            try ConstraintSolver.resolve(
                world: &world,
                timeStep: 1,
                configuration: ConstraintSolverConfiguration(velocityIterations: 0)
            )
        }
        #expect(throws: MatterError.invalidConstraintSolverConfiguration) {
            try ConstraintSolver.resolve(
                world: &world,
                timeStep: 1,
                configuration: ConstraintSolverConfiguration(positionIterations: 0)
            )
        }
        #expect(throws: MatterError.invalidConstraintSolverConfiguration) {
            try Engine(
                constraintSolverConfiguration: ConstraintSolverConfiguration(
                    positionIterations: 0
                )
            )
        }

        let body = try world.add(Bodies.circle(at: .zero, radius: 1))
        _ = try world.addConstraint(Constraints.pin(body, to: .zero))
        world.replaceBodies([])
        #expect(throws: MatterError.unknownBody(body)) {
            try ConstraintSolver.resolve(world: &world, timeStep: 1)
        }

        var corruptedDefinition = try ConstraintDefinition(
            first: .fixed(.zero),
            second: .body(body),
            damping: 1,
            angularStiffness: 1,
            maximumImpulse: 1
        )
        corruptedDefinition.second = .fixed(.zero)
        let corrupted = Constraint(
            id: ConstraintID(rawValue: 999),
            definition: corruptedDefinition,
            length: 0,
            referenceAngle: 0
        )
        world.replaceConstraints([corrupted])
        #expect(try ConstraintSolver.resolve(world: &world, timeStep: 1).isEmpty)
        #expect(world.constraints == [corrupted])
    }

    @Test("Constraint snapshots round-trip and exhausted identifiers cannot wrap")
    func codableAndExhaustion() throws {
        var world = World()
        let body = try world.add(Bodies.circle(at: Vector(x: 2, y: 0), radius: 1))
        _ = try world.addConstraint(
            Constraints.pin(
                body,
                localAnchor: Vector(x: 1, y: 0),
                to: .zero,
                damping: 0.2,
                maximumImpulse: 5
            )
        )
        let data = try JSONEncoder().encode(world)
        #expect(try JSONDecoder().decode(World.self, from: data) == world)

        let exhausted = Data(
            #"{"bodies":[],"composites":[],"constraints":[],"nextBodyIdentifier":0,"nextCompositeIdentifier":0,"nextConstraintIdentifier":18446744073709551615}"#
                .utf8
        )
        var decoded = try JSONDecoder().decode(World.self, from: exhausted)
        let missing = BodyID(rawValue: 1)
        #expect(throws: MatterError.unknownBody(missing)) {
            try decoded.addConstraint(Constraints.pin(missing, to: .zero))
        }

        let bodyDefinition = try Bodies.circle(at: .zero, radius: 1)
        let identifier = try decoded.add(bodyDefinition)
        #expect(throws: MatterError.constraintIdentifierExhausted) {
            try decoded.addConstraint(Constraints.pin(identifier, to: .zero))
        }
    }

    #if canImport(Metal)
        @Test("Engine solves and reports broken constraints")
        func engineIntegration() async throws {
            guard MetalBackend.isAvailable else { return }
            let engine = try Engine(gravity: .zero, fixedTimeStep: 1)
            let body = try await engine.add(Bodies.circle(at: Vector(x: 10, y: 0), radius: 1))
            let constraint = try await engine.addConstraint(
                Constraints.pin(body, to: .zero, length: 0, maximumImpulse: 1)
            )
            let result = try await engine.stepWithEvents()
            #expect(result.brokenConstraints == [constraint])
            #expect(result.world.constraints.isEmpty)

            let retained = try await engine.addConstraint(
                Constraints.pin(body, to: Vector(x: 10, y: 0))
            )
            let composite = try await engine.addComposite()
            try await engine.assignConstraint(retained, to: composite)
            #expect(await engine.removeConstraint(withID: retained)?.id == retained)
        }
    #endif
}
