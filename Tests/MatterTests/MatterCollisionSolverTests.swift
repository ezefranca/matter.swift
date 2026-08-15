import Testing

@testable import Matter

@Suite("Matter collision response")
struct MatterCollisionSolverTests {
    @Test("Configuration validation covers every unsupported value family")
    func solverConfigurationValidation() throws {
        #expect(SolverConfiguration.standard.velocityIterations == 8)
        #expect(SolverConfiguration.standard.positionIterations == 3)
        #expect(SolverConfiguration.standard.positionCorrection == 0.8)
        #expect(SolverConfiguration.standard.restitutionVelocityThreshold == 1)

        let invalidConfigurations = [
            SolverConfiguration(velocityIterations: 0),
            SolverConfiguration(positionIterations: 0),
            SolverConfiguration(positionCorrection: .nan),
            SolverConfiguration(positionCorrection: -0.1),
            SolverConfiguration(positionCorrection: 1.1),
            SolverConfiguration(restitutionVelocityThreshold: .infinity),
            SolverConfiguration(restitutionVelocityThreshold: -1),
        ]
        for configuration in invalidConfigurations {
            var world = World()
            #expect(throws: MatterError.invalidSolverConfiguration) {
                try CollisionSolver.resolve(world: &world, configuration: configuration)
            }
        }

        #expect(throws: MatterError.invalidSolverConfiguration) {
            try Engine(solverConfiguration: SolverConfiguration(velocityIterations: 0))
        }
    }

    @Test("Elastic equal-mass circles exchange normal velocity")
    func elasticCollision() throws {
        var world = World()
        let material = BodyMaterial(restitution: 1, friction: 0, staticFriction: 0, slop: 0)
        let first = try world.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: -0.75, y: 0),
                velocity: Vector(x: 1, y: 0),
                material: material
            )
        )
        let second = try world.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: 0.75, y: 0),
                velocity: Vector(x: -1, y: 0),
                material: material
            )
        )

        let collisions = try CollisionSolver.resolve(
            world: &world,
            configuration: SolverConfiguration(
                velocityIterations: 2,
                positionIterations: 1,
                positionCorrection: 1,
                restitutionVelocityThreshold: 0
            )
        )
        let bodyA = try #require(world.body(withID: first))
        let bodyB = try #require(world.body(withID: second))

        #expect(collisions.count == 1)
        #expect(abs(bodyA.velocity.x + 1) < 0.000_01)
        #expect(abs(bodyB.velocity.x - 1) < 0.000_01)
        #expect(abs(bodyA.position.x + 1) < 0.000_01)
        #expect(abs(bodyB.position.x - 1) < 0.000_01)
    }

    @Test("Restitution threshold suppresses low-speed bounce")
    func restitutionThreshold() throws {
        var world = World()
        let material = BodyMaterial(restitution: 1, friction: 0, staticFriction: 0)
        let first = try world.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: -0.9, y: 0),
                velocity: Vector(x: 0.1, y: 0),
                material: material
            )
        )
        let second = try world.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: 0.9, y: 0),
                velocity: Vector(x: -0.1, y: 0),
                material: material
            )
        )

        try CollisionSolver.resolve(
            world: &world,
            configuration: SolverConfiguration(velocityIterations: 1, positionIterations: 1)
        )
        #expect(abs(try #require(world.body(withID: first)).velocity.x) < 0.000_01)
        #expect(abs(try #require(world.body(withID: second)).velocity.x) < 0.000_01)
    }

    @Test("Static and dynamic friction reduce tangent speed and create spin")
    func frictionBranchesAndAngularImpulse() throws {
        var staticFrictionWorld = try frictionWorld(
            tangentSpeed: 0.1, staticFriction: 1, friction: 0.2)
        let staticMovingID = staticFrictionWorld.bodies[1].id
        try CollisionSolver.resolve(
            world: &staticFrictionWorld,
            configuration: SolverConfiguration(velocityIterations: 1, positionIterations: 1)
        )
        let staticResult = try #require(staticFrictionWorld.body(withID: staticMovingID))
        #expect(abs(staticResult.velocity.y) < 0.1)
        #expect(staticResult.angularVelocity != 0)

        var dynamicFrictionWorld = try frictionWorld(
            tangentSpeed: 10,
            staticFriction: 0.01,
            friction: 0.2
        )
        let dynamicMovingID = dynamicFrictionWorld.bodies[1].id
        try CollisionSolver.resolve(
            world: &dynamicFrictionWorld,
            configuration: SolverConfiguration(velocityIterations: 1, positionIterations: 1)
        )
        let dynamicResult = try #require(dynamicFrictionWorld.body(withID: dynamicMovingID))
        #expect(dynamicResult.velocity.y < 10)
        #expect(dynamicResult.velocity.y > 9)
        #expect(dynamicResult.angularVelocity != 0)
    }

    @Test("Sensors, separating bodies, slop, and static pairs do not receive response")
    func responseBypassPaths() throws {
        var sensorWorld = World()
        let sensor = try sensorWorld.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: -0.5, y: 0),
                velocity: Vector(x: 1, y: 0),
                isSensor: true
            )
        )
        let sensed = try sensorWorld.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: 0.5, y: 0),
                velocity: Vector(x: -1, y: 0)
            )
        )
        let sensorCollisions = try CollisionSolver.resolve(world: &sensorWorld)
        #expect(sensorCollisions.first?.isSensor == true)
        #expect(sensorWorld.body(withID: sensor)?.velocity.x == 1)
        #expect(sensorWorld.body(withID: sensed)?.velocity.x == -1)
        #expect(sensorWorld.body(withID: sensor)?.position.x == -0.5)

        var separatingWorld = World()
        let separating = try separatingWorld.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: -0.9, y: 0),
                velocity: Vector(x: -1, y: 0)
            )
        )
        _ = try separatingWorld.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: 0.9, y: 0),
                velocity: Vector(x: 1, y: 0)
            )
        )
        try CollisionSolver.resolve(world: &separatingWorld)
        #expect(separatingWorld.body(withID: separating)?.velocity.x == -1)

        var slopWorld = World()
        let slopBody = try slopWorld.add(Bodies.circle(at: Vector(x: -0.995, y: 0), radius: 1))
        _ = try slopWorld.add(Bodies.circle(at: Vector(x: 0.995, y: 0), radius: 1))
        try CollisionSolver.resolve(world: &slopWorld)
        #expect(slopWorld.body(withID: slopBody)?.position.x == -0.995)

        var staticWorld = World()
        let firstStatic = try staticWorld.add(
            Bodies.circle(at: Vector(x: -0.5, y: 0), radius: 1, isStatic: true)
        )
        _ = try staticWorld.add(
            Bodies.circle(at: Vector(x: 0.5, y: 0), radius: 1, isStatic: true)
        )
        try CollisionSolver.resolve(world: &staticWorld)
        #expect(staticWorld.body(withID: firstStatic)?.position.x == -0.5)

        var emptyWorld = World()
        #expect(try CollisionSolver.resolve(world: &emptyWorld).isEmpty)
    }

    @Test("The CPU reference step integrates before resolving contacts")
    func referencePhysicsStep() throws {
        var world = World()
        let material = BodyMaterial(restitution: 1, friction: 0, staticFriction: 0, slop: 0)
        let first = try world.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: -1.5, y: 0),
                velocity: Vector(x: 1, y: 0),
                material: material
            )
        )
        let second = try world.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: 1.5, y: 0),
                velocity: Vector(x: -1, y: 0),
                material: material
            )
        )

        let collisions = try ReferencePhysics.step(
            world: &world,
            gravity: .zero,
            timeStep: 0.5,
            solver: SolverConfiguration(
                velocityIterations: 1,
                positionIterations: 1,
                restitutionVelocityThreshold: 0
            )
        )
        #expect(collisions.count == 1)
        #expect(world.body(withID: first)?.velocity.x == -1)
        #expect(world.body(withID: second)?.velocity.x == 1)
    }

    #if canImport(Metal)
        @Test("Engine runs Metal integration followed by CPU collision response")
        func engineCollisionResponse() async throws {
            guard MetalBackend.isAvailable else { return }
            let configuration = SolverConfiguration(
                velocityIterations: 1,
                positionIterations: 1,
                restitutionVelocityThreshold: 0
            )
            let engine = try Engine(
                gravity: .zero,
                fixedTimeStep: 0.5,
                solverConfiguration: configuration
            )
            let material = BodyMaterial(restitution: 1, friction: 0, staticFriction: 0, slop: 0)
            let first = try await engine.add(
                BodyDefinition(
                    shape: .circle(radius: 1),
                    position: Vector(x: -1.5, y: 0),
                    velocity: Vector(x: 1, y: 0),
                    material: material
                )
            )
            let second = try await engine.add(
                BodyDefinition(
                    shape: .circle(radius: 1),
                    position: Vector(x: 1.5, y: 0),
                    velocity: Vector(x: -1, y: 0),
                    material: material
                )
            )

            let snapshot = try await engine.step()
            #expect(await engine.solverConfiguration == configuration)
            #expect(snapshot.body(withID: first)?.velocity.x == -1)
            #expect(snapshot.body(withID: second)?.velocity.x == 1)
        }
    #endif

    private func frictionWorld(
        tangentSpeed: Float,
        staticFriction: Float,
        friction: Float
    ) throws -> World {
        let material = BodyMaterial(
            restitution: 0,
            friction: friction,
            staticFriction: staticFriction,
            slop: 0
        )
        var world = World()
        _ = try world.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: .zero,
                isStatic: true,
                material: material
            )
        )
        _ = try world.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: Vector(x: 1.5, y: 0),
                velocity: Vector(x: -1, y: tangentSpeed),
                material: material
            )
        )
        return world
    }
}
