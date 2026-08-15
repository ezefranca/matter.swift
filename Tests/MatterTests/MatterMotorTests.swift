import Foundation
import Testing

@testable import Matter

@Suite("Matter rotational locks and motors")
struct MatterMotorTests {
    @Test("Motor and rotational-lock factories preserve explicit configuration")
    func factories() throws {
        let first = BodyID(rawValue: 1)
        let second = BodyID(rawValue: 2)
        let motor = try Constraints.motor(
            first,
            pivot: Vector(x: 3, y: 4),
            targetSpeed: 2,
            maximumTorque: 5,
            damping: 0.1
        )
        #expect(motor.first == .fixed(Vector(x: 3, y: 4)))
        #expect(motor.second == .body(first))
        #expect(motor.length == 0)
        #expect(motor.motorSpeed == 2)
        #expect(motor.maximumMotorTorque == 5)
        #expect(motor.damping == 0.1)
        #expect(motor.label == "Motor")

        let lock = try Constraints.rotationalLock(
            between: first,
            and: second,
            length: 6,
            stiffness: 0.8,
            damping: 0.2
        )
        #expect(lock.angularStiffness == 1)
        #expect(lock.length == 6)
        #expect(lock.label == "Rotational Lock")
    }

    @Test("Definitions reject invalid motor configuration")
    func validation() {
        let body = BodyID(rawValue: 1)
        #expect(throws: MatterError.invalidConstraint) {
            try ConstraintDefinition(
                first: .fixed(.zero),
                second: .body(body),
                motorSpeed: .nan
            )
        }
        #expect(throws: MatterError.invalidConstraint) {
            try ConstraintDefinition(
                first: .fixed(.zero),
                second: .body(body),
                motorSpeed: 1,
                maximumMotorTorque: 0
            )
        }
        #expect(throws: MatterError.invalidConstraint) {
            try ConstraintDefinition(
                first: .fixed(.zero),
                second: .body(body),
                motorSpeed: 1,
                maximumMotorTorque: .infinity
            )
        }
        #expect(throws: MatterError.invalidConstraint) {
            try ConstraintDefinition(
                first: .fixed(.zero),
                second: .body(body),
                maximumMotorTorque: 1
            )
        }
    }

    @Test("Uncapped motors reach target world and relative angular speeds")
    func uncappedMotors() throws {
        let configuration = ConstraintSolverConfiguration(
            velocityIterations: 1,
            positionIterations: 1
        )
        var world = World()
        let body = try world.add(Bodies.circle(at: .zero, radius: 1))
        _ = try world.addConstraint(
            Constraints.motor(body, pivot: .zero, targetSpeed: 2)
        )
        try ConstraintSolver.resolve(
            world: &world,
            timeStep: 1,
            configuration: configuration
        )
        #expect(abs(try #require(world.body(withID: body)).angularVelocity - 2) < 0.000_01)

        var pairWorld = World()
        let first = try pairWorld.add(Bodies.circle(at: .zero, radius: 1))
        let second = try pairWorld.add(Bodies.circle(at: Vector(x: 4, y: 0), radius: 1))
        _ = try pairWorld.addConstraint(
            ConstraintDefinition(
                first: .body(first),
                second: .body(second),
                stiffness: 0,
                motorSpeed: 1
            )
        )
        try ConstraintSolver.resolve(
            world: &pairWorld,
            timeStep: 1,
            configuration: configuration
        )
        let firstBody = try #require(pairWorld.body(withID: first))
        let secondBody = try #require(pairWorld.body(withID: second))
        #expect(abs((secondBody.angularVelocity - firstBody.angularVelocity) - 1) < 0.000_01)
    }

    @Test("Torque caps bound total motor impulse across velocity iterations")
    func torqueLimit() throws {
        var world = World()
        let body = try world.add(Bodies.circle(at: .zero, radius: 1))
        _ = try world.addConstraint(
            Constraints.motor(
                body,
                pivot: .zero,
                targetSpeed: 10,
                maximumTorque: 0.5
            )
        )
        try ConstraintSolver.resolve(
            world: &world,
            timeStep: 1,
            configuration: ConstraintSolverConfiguration(
                velocityIterations: 2,
                positionIterations: 1
            )
        )
        #expect(abs(try #require(world.body(withID: body)).angularVelocity - 1) < 0.000_01)
    }

    @Test("Body-to-fixed damping and angular locks use consistent endpoint signs")
    func reversedEndpointSigns() throws {
        var world = World()
        let body = try world.add(
            BodyDefinition(
                shape: .rectangle(width: 2, height: 1),
                position: .zero,
                angularVelocity: 2
            )
        )
        _ = try world.addConstraint(
            ConstraintDefinition(
                first: .body(body),
                second: .fixed(.zero),
                length: 0,
                stiffness: 0,
                damping: 1,
                angularStiffness: 1
            )
        )
        try world.updateBody(withID: body) { try $0.setAngle(1) }
        try ConstraintSolver.resolve(
            world: &world,
            timeStep: 1,
            configuration: ConstraintSolverConfiguration(
                velocityIterations: 1,
                positionIterations: 1
            )
        )
        let result = try #require(world.body(withID: body))
        #expect(abs(result.angularVelocity) < 0.000_01)
        #expect(abs(result.angle) < 0.000_01)
    }

    @Test("Static motor endpoints remain unchanged")
    func staticMotor() throws {
        var world = World()
        let body = try world.add(Bodies.circle(at: .zero, radius: 1, isStatic: true))
        _ = try world.addConstraint(
            Constraints.motor(body, pivot: .zero, targetSpeed: 2)
        )
        try ConstraintSolver.resolve(world: &world, timeStep: 1)
        #expect(world.body(withID: body)?.angularVelocity == 0)
    }

    @Test("Motor fields round-trip through world snapshots")
    func codable() throws {
        var world = World()
        let body = try world.add(Bodies.circle(at: .zero, radius: 1))
        _ = try world.addConstraint(
            Constraints.motor(
                body,
                pivot: .zero,
                targetSpeed: -3,
                maximumTorque: 4
            )
        )
        let data = try JSONEncoder().encode(world)
        #expect(try JSONDecoder().decode(World.self, from: data) == world)
    }

    #if canImport(Metal)
        @Test("Engine applies motors after Metal integration")
        func engineMotor() async throws {
            guard MetalBackend.isAvailable else { return }
            let engine = try Engine(
                gravity: .zero,
                fixedTimeStep: 1,
                constraintSolverConfiguration: ConstraintSolverConfiguration(
                    velocityIterations: 1,
                    positionIterations: 1
                )
            )
            let body = try await engine.add(Bodies.circle(at: .zero, radius: 1))
            _ = try await engine.addConstraint(
                Constraints.motor(body, pivot: .zero, targetSpeed: 2)
            )
            let result = try await engine.step()
            #expect(abs(try #require(result.body(withID: body)).angularVelocity - 2) < 0.000_01)
        }
    #endif
}
