import Foundation
import Testing

@testable import Matter

@Suite("Matter sleeping and island management")
struct MatterSleepingTests {
    @Test("Sleeping configuration validates thresholds and round-trips")
    func configuration() throws {
        let standard = SleepingConfiguration.standard
        #expect(standard.enabled)
        #expect(SleepingConfiguration.disabled.enabled == false)
        #expect(standard.linearVelocityThreshold == 0.05)
        #expect(standard.angularVelocityThreshold == 0.05)
        #expect(standard.minimumQuietTime == 0.5)
        let data = try JSONEncoder().encode(standard)
        #expect(try JSONDecoder().decode(SleepingConfiguration.self, from: data) == standard)

        let invalid = [
            SleepingConfiguration(linearVelocityThreshold: -.infinity),
            SleepingConfiguration(linearVelocityThreshold: -1),
            SleepingConfiguration(angularVelocityThreshold: .nan),
            SleepingConfiguration(angularVelocityThreshold: -1),
            SleepingConfiguration(minimumQuietTime: .infinity),
            SleepingConfiguration(minimumQuietTime: 0),
        ]
        for configuration in invalid {
            var world = World()
            var state = SleepingState()
            #expect(throws: MatterError.invalidSleepingConfiguration) {
                try SleepingManager.update(
                    world: &world,
                    state: &state,
                    timeStep: 0.1,
                    configuration: configuration
                )
            }
        }

        var world = World()
        var state = SleepingState()
        #expect(throws: MatterError.invalidTimeStep) {
            try SleepingManager.update(world: &world, state: &state, timeStep: 0)
        }
    }

    @Test("Islands connect dynamic contacts and constraints without static or sensor bridges")
    func islands() throws {
        var world = World()
        let first = try world.add(Bodies.circle(at: Vector(x: 0, y: 0), radius: 1))
        let second = try world.add(Bodies.circle(at: Vector(x: 1.5, y: 0), radius: 1))
        let third = try world.add(Bodies.circle(at: Vector(x: 10, y: 0), radius: 1))
        let fourth = try world.add(Bodies.circle(at: Vector(x: 12, y: 0), radius: 1))
        let fifth = try world.add(Bodies.circle(at: Vector(x: 10.5, y: 0), radius: 1))
        let staticBody = try world.add(
            Bodies.rectangle(at: Vector(x: 5, y: 0), width: 20, height: 2, isStatic: true)
        )
        _ = try world.addConstraint(
            ConstraintDefinition(
                first: .body(third),
                second: .body(fourth),
                length: 2
            )
        )
        _ = try world.addConstraint(
            ConstraintDefinition(first: .body(first), second: .body(staticBody), length: 5)
        )
        _ = try world.addConstraint(
            Constraints.pin(second, to: Vector(x: 1.5, y: -2), length: 2)
        )
        let sensorDefinition = try BodyDefinition(
            shape: .circle(radius: 2),
            position: Vector(x: 6, y: 0),
            isSensor: true
        )
        _ = try world.add(sensorDefinition)

        let detected = CollisionDetector.collisions(in: world)
        let islands = IslandManager.islands(in: world, collisions: detected)
        #expect(islands.map(\.bodyIDs).contains([first, second]))
        #expect(islands.map(\.bodyIDs).contains([third, fourth, fifth]))
        #expect(islands.allSatisfy { !$0.bodyIDs.contains(staticBody) })
        #expect(islands == islands.sorted())
        #expect(islands[0].identifier == islands[0].bodyIDs[0])
        #expect(!(islands[0] < islands[0]))

        let automaticallyDetected = IslandManager.islands(in: world)
        #expect(automaticallyDetected == islands)
        #expect(IslandManager.islands(in: World()).isEmpty)
    }

    @Test("Body APIs wake motion and keep static bodies permanently nonsleeping")
    func bodyWakeSemantics() throws {
        var world = World()
        let sleeping = try world.add(
            BodyDefinition(
                shape: .rectangle(width: 2, height: 4),
                position: .zero,
                velocity: Vector(x: 9, y: 9),
                angularVelocity: 3,
                mass: 2,
                isSleeping: true
            )
        )
        let immovable = try world.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: .zero,
                isStatic: true,
                isSleeping: true
            )
        )
        var body = try #require(world.body(withID: sleeping))
        #expect(body.isSleeping)
        #expect(body.velocity == .zero)
        #expect(body.angularVelocity == 0)
        #expect(body.inverseMass == 0)
        #expect(body.inverseInertia == 0)

        body.applyForce(Vector(x: 1, y: 0))
        #expect(!body.isSleeping)
        body.setSleeping(true)
        body.applyForce(Vector(x: 0, y: 1), at: Vector(x: 1, y: 0))
        #expect(!body.isSleeping)
        body.setSleeping(true)
        body.applyTorque(1)
        #expect(!body.isSleeping)
        body.setSleeping(true)
        try body.setPosition(Vector(x: 2, y: 3))
        #expect(!body.isSleeping)
        body.setSleeping(true)
        try body.setAngle(0.5)
        #expect(!body.isSleeping)
        body.setSleeping(true)
        try body.setVelocity(Vector(x: 2, y: 0))
        #expect(!body.isSleeping)
        body.setSleeping(true)
        try body.setAngularVelocity(2)
        #expect(!body.isSleeping)

        var staticBody = try #require(world.body(withID: immovable))
        #expect(!staticBody.isSleeping)
        staticBody.setSleeping(true)
        #expect(!staticBody.isSleeping)
    }

    @Test("Quiet islands sleep together and force wakes every connected body")
    func islandTransitions() throws {
        var world = World()
        let first = try world.add(Bodies.circle(at: .zero, radius: 1))
        let second = try world.add(Bodies.circle(at: Vector(x: 3, y: 0), radius: 1))
        _ = try world.addConstraint(
            ConstraintDefinition(first: .body(first), second: .body(second), length: 3)
        )
        var state = SleepingState()
        let configuration = SleepingConfiguration(
            linearVelocityThreshold: 0.1,
            angularVelocityThreshold: 0.1,
            minimumQuietTime: 0.2
        )

        let firstEvents = try SleepingManager.update(
            world: &world,
            state: &state,
            timeStep: 0.1,
            configuration: configuration
        )
        #expect(firstEvents.isEmpty)
        #expect(state.trackedBodies == [first, second])
        #expect(state.quietTime(for: first) == 0.1)
        #expect(state.quietTime(for: BodyID(rawValue: 999)) == nil)

        let sleepEvents = try SleepingManager.update(
            world: &world,
            state: &state,
            timeStep: 0.1,
            configuration: configuration
        )
        #expect(
            sleepEvents == [
                SleepingEvent(phase: .started, body: first),
                SleepingEvent(phase: .started, body: second),
            ])
        #expect(world.bodies.filter { !$0.isStatic }.allSatisfy { $0.isSleeping })
        #expect(SleepingPhase.allCases == [.started, .ended])
        #expect(state.sleepingBodies == [first, second])

        try world.updateBody(withID: first) { $0.setSleeping(false) }
        let explicitWakeEvents = SleepingManager.prepareForStep(world: &world)
        #expect(explicitWakeEvents == [SleepingEvent(phase: .ended, body: second)])
        let restartedQuietTime = try SleepingManager.update(
            world: &world,
            state: &state,
            timeStep: 0.1,
            configuration: configuration
        )
        #expect(restartedQuietTime.isEmpty)
        #expect(state.quietTime(for: first) == 0.1)
        #expect(world.bodies.allSatisfy { !$0.isSleeping })
        _ = try SleepingManager.update(
            world: &world,
            state: &state,
            timeStep: 0.1,
            configuration: configuration
        )

        try world.applyForce(Vector(x: 1, y: 0), to: first)
        let wakeEvents = SleepingManager.prepareForStep(world: &world)
        #expect(wakeEvents == [SleepingEvent(phase: .ended, body: second)])
        #expect(world.bodies.allSatisfy { !$0.isSleeping })

        let activeEvents = try SleepingManager.update(
            world: &world,
            state: &state,
            timeStep: 0.1,
            configuration: configuration
        )
        #expect(activeEvents.isEmpty)
        #expect(state.quietTime(for: first) == 0)
        #expect(state.quietTime(for: second) == 0)

        var contactWorld = World()
        let awake = try contactWorld.add(Bodies.circle(at: .zero, radius: 1))
        let asleep = try contactWorld.add(Bodies.circle(at: Vector(x: 1, y: 0), radius: 1))
        try contactWorld.updateBody(withID: asleep) { $0.setSleeping(true) }
        let contactWake = SleepingManager.prepareForStep(world: &contactWorld)
        #expect(contactWake == [SleepingEvent(phase: .ended, body: asleep)])
        #expect(contactWorld.body(withID: awake)?.isSleeping == false)
    }

    @Test("Disabled sleeping wakes bodies, resets state, and prunes removals")
    func disabledAndPruning() throws {
        var world = World()
        let first = try world.add(Bodies.circle(at: .zero, radius: 1))
        let second = try world.add(Bodies.circle(at: Vector(x: 5, y: 0), radius: 1))
        var state = SleepingState()
        _ = try SleepingManager.update(
            world: &world,
            state: &state,
            timeStep: 0.1,
            configuration: SleepingConfiguration(minimumQuietTime: 1)
        )
        #expect(state.trackedBodies == [first, second])
        _ = world.removeBody(withID: second)
        _ = try SleepingManager.update(
            world: &world,
            state: &state,
            timeStep: 0.1,
            configuration: SleepingConfiguration(minimumQuietTime: 1)
        )
        #expect(state.trackedBodies == [first])

        try world.updateBody(withID: first) { $0.setSleeping(true) }
        let events = try SleepingManager.update(
            world: &world,
            state: &state,
            timeStep: 0.1,
            configuration: .disabled
        )
        #expect(events == [SleepingEvent(phase: .ended, body: first)])
        #expect(state.trackedBodies.isEmpty)
        #expect(world.body(withID: first)?.isSleeping == false)
        #expect(state.sleepingBodies.isEmpty)

        #expect(
            try SleepingManager.update(
                world: &world,
                state: &state,
                timeStep: 0.1,
                configuration: .disabled
            ).isEmpty)
        state.reset()
        #expect(state.trackedBodies.isEmpty)
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(SleepingState.self, from: data) == state)
    }

    @Test("Active sleeping snapshots wake during post-solve classification")
    func defensiveActiveWake() throws {
        var world = World()
        let identifier = try world.add(Bodies.circle(at: .zero, radius: 1))
        try world.updateBody(withID: identifier) { body in
            body.setSleeping(true)
            body.replaceKinematics(
                position: body.position,
                angle: body.angle,
                velocity: Vector(x: 1, y: 0),
                angularVelocity: 0
            )
        }
        var state = SleepingState()
        let events = try SleepingManager.update(
            world: &world,
            state: &state,
            timeStep: 0.1
        )
        #expect(events == [SleepingEvent(phase: .ended, body: identifier)])
        #expect(world.body(withID: identifier)?.isSleeping == false)
    }

    @Test("Stateful reference ticks expose sleep and collision lifecycle events")
    func referencePhysics() throws {
        var world = World()
        let body = try world.add(Bodies.circle(at: .zero, radius: 1))
        var tracker = CollisionTracker()
        var solverState = CollisionSolverState()
        var sleepingState = SleepingState()
        let sleeping = SleepingConfiguration(
            linearVelocityThreshold: 0.1,
            angularVelocityThreshold: 0.1,
            minimumQuietTime: 0.2
        )

        let first = try ReferencePhysics.stepWithEvents(
            world: &world,
            collisionTracker: &tracker,
            collisionSolverState: &solverState,
            sleepingState: &sleepingState,
            gravity: .zero,
            timeStep: 0.1,
            sleeping: sleeping
        )
        #expect(first.sleepingEvents.isEmpty)
        let second = try ReferencePhysics.stepWithEvents(
            world: &world,
            collisionTracker: &tracker,
            collisionSolverState: &solverState,
            sleepingState: &sleepingState,
            gravity: .zero,
            timeStep: 0.1,
            sleeping: sleeping
        )
        #expect(second.tickCount == 1)
        #expect(second.sleepingEvents == [SleepingEvent(phase: .started, body: body)])
        #expect(second.world.body(withID: body)?.isSleeping == true)
        #expect(second.collisions.isEmpty)
        #expect(second.collisionEvents.isEmpty)
        #expect(second.brokenConstraints.isEmpty)

        let disabled = try ReferencePhysics.stepWithEvents(
            world: &world,
            collisionTracker: &tracker,
            collisionSolverState: &solverState,
            sleepingState: &sleepingState,
            gravity: .zero,
            timeStep: 0.1
        )
        #expect(disabled.sleepingEvents == [SleepingEvent(phase: .ended, body: body)])

        #expect(throws: MatterError.invalidTimeStep) {
            try ReferencePhysics.stepWithEvents(
                world: &world,
                collisionTracker: &tracker,
                collisionSolverState: &solverState,
                sleepingState: &sleepingState,
                gravity: .zero,
                timeStep: 0
            )
        }
        #expect(throws: MatterError.invalidSolverConfiguration) {
            try ReferencePhysics.stepWithEvents(
                world: &world,
                collisionTracker: &tracker,
                collisionSolverState: &solverState,
                sleepingState: &sleepingState,
                gravity: .zero,
                timeStep: 0.1,
                solver: SolverConfiguration(velocityIterations: 0)
            )
        }
        #expect(throws: MatterError.invalidConstraintSolverConfiguration) {
            try ReferencePhysics.stepWithEvents(
                world: &world,
                collisionTracker: &tracker,
                collisionSolverState: &solverState,
                sleepingState: &sleepingState,
                gravity: .zero,
                timeStep: 0.1,
                constraintSolver: ConstraintSolverConfiguration(positionIterations: 0)
            )
        }
    }

    #if canImport(Metal)
        @Test("Engine preserves Metal sleeping parity and resets state")
        func engine() async throws {
            guard MetalBackend.isAvailable else { return }
            #expect(throws: MatterError.invalidSleepingConfiguration) {
                try Engine(
                    sleepingConfiguration: SleepingConfiguration(minimumQuietTime: 0)
                )
            }

            let engine = try Engine(
                gravity: .zero,
                fixedTimeStep: 0.1,
                sleepingConfiguration: SleepingConfiguration(
                    linearVelocityThreshold: 0.1,
                    angularVelocityThreshold: 0.1,
                    minimumQuietTime: 0.2
                )
            )
            let identifier = try await engine.add(Bodies.circle(at: .zero, radius: 1))
            let result = try await engine.stepWithEvents(ticks: 2)
            #expect(result.sleepingEvents == [SleepingEvent(phase: .started, body: identifier)])
            #expect(result.world.body(withID: identifier)?.isSleeping == true)
            #expect(await engine.sleepingStateSnapshot().quietTime(for: identifier) == 0.2)

            try await engine.applyTorque(1, to: identifier)
            let wakeResult = try await engine.stepWithEvents()
            #expect(wakeResult.sleepingEvents.isEmpty)
            #expect(wakeResult.world.body(withID: identifier)?.isSleeping == false)

            await engine.reset()
            #expect(await engine.sleepingStateSnapshot().trackedBodies.isEmpty)

            let runnerEngine = try Engine(
                gravity: .zero,
                fixedTimeStep: 0.1,
                sleepingConfiguration: SleepingConfiguration(minimumQuietTime: 0.1)
            )
            let runnerBody = try await runnerEngine.add(Bodies.circle(at: .zero, radius: 1))
            let runner = try Runner(engine: runnerEngine)
            let update = try await runner.advance(by: 0.1)
            #expect(update.sleepingEvents == [SleepingEvent(phase: .started, body: runnerBody)])
        }
    #endif
}
