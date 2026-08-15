import Foundation
import Testing

@testable import Matter

@Suite("Matter bounded continuous collision substeps")
struct MatterContinuousCollisionTests {
    @Test("Configuration and plans validate and round-trip")
    func configuration() throws {
        let standard = ContinuousCollisionConfiguration.standard
        #expect(standard.enabled)
        #expect(standard.maximumMotionPerSubstep == 1)
        #expect(standard.maximumSubsteps == 16)
        #expect(!ContinuousCollisionConfiguration.disabled.enabled)
        let data = try JSONEncoder().encode(standard)
        #expect(
            try JSONDecoder().decode(ContinuousCollisionConfiguration.self, from: data)
                == standard)

        let invalid = [
            ContinuousCollisionConfiguration(maximumMotionPerSubstep: .nan),
            ContinuousCollisionConfiguration(maximumMotionPerSubstep: 0),
            ContinuousCollisionConfiguration(maximumSubsteps: 0),
        ]
        for configuration in invalid {
            #expect(throws: MatterError.invalidContinuousCollisionConfiguration) {
                try ContinuousCollisionPlanner.plan(
                    for: World(),
                    gravity: .zero,
                    timeStep: 0.1,
                    configuration: configuration
                )
            }
        }
        #expect(throws: MatterError.invalidTimeStep) {
            try ContinuousCollisionPlanner.plan(
                for: World(),
                gravity: .zero,
                timeStep: 0
            )
        }
        #expect(throws: MatterError.invalidVector) {
            try ContinuousCollisionPlanner.plan(
                for: World(),
                gravity: Vector(x: .nan, y: 0),
                timeStep: 0.1
            )
        }

        let empty = try ContinuousCollisionPlanner.plan(
            for: World(),
            gravity: .zero,
            timeStep: 0.25
        )
        #expect(empty.substepCount == 1)
        #expect(empty.substepTime == 0.25)
        #expect(empty.maximumPredictedMotion == 0)
        #expect(!empty.isClamped)
        let planData = try JSONEncoder().encode(empty)
        #expect(try JSONDecoder().decode(ContinuousCollisionPlan.self, from: planData) == empty)

        var referenceWorld = World()
        var tracker = CollisionTracker()
        var solverState = CollisionSolverState()
        var sleepingState = SleepingState()
        #expect(throws: MatterError.invalidVector) {
            try ReferencePhysics.stepWithEvents(
                world: &referenceWorld,
                collisionTracker: &tracker,
                collisionSolverState: &solverState,
                sleepingState: &sleepingState,
                gravity: Vector(x: .infinity, y: 0),
                timeStep: 0.1
            )
        }
        #expect(throws: MatterError.invalidContinuousCollisionConfiguration) {
            try ReferencePhysics.stepWithEvents(
                world: &referenceWorld,
                collisionTracker: &tracker,
                collisionSolverState: &solverState,
                sleepingState: &sleepingState,
                gravity: .zero,
                timeStep: 0.1,
                continuousCollision: ContinuousCollisionConfiguration(maximumSubsteps: 0)
            )
        }
    }

    @Test("Planner bounds translation, rotation, disabled mode, and overflow")
    func planning() throws {
        var world = World()
        _ = try world.add(
            BodyDefinition(
                shape: .rectangle(width: 2, height: 2),
                position: .zero,
                velocity: Vector(x: 10, y: 0),
                angularVelocity: 2
            )
        )
        _ = try world.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: .zero,
                velocity: Vector(x: 1_000, y: 0),
                isStatic: true
            )
        )
        _ = try world.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: .zero,
                velocity: Vector(x: 1_000, y: 0),
                isSleeping: true
            )
        )

        let plan = try ContinuousCollisionPlanner.plan(
            for: world,
            gravity: .zero,
            timeStep: 1,
            configuration: ContinuousCollisionConfiguration(
                maximumMotionPerSubstep: 3,
                maximumSubsteps: 16
            )
        )
        #expect(plan.substepCount == 5)
        #expect(plan.maximumPredictedMotion > 12.8)
        #expect(plan.maximumPredictedMotion < 12.9)
        #expect(!plan.isClamped)

        let disabled = try ContinuousCollisionPlanner.plan(
            for: world,
            gravity: .zero,
            timeStep: 1,
            configuration: .disabled
        )
        #expect(disabled.substepCount == 1)
        #expect(!disabled.isClamped)

        try world.updateBody(withID: world.bodies[0].id) { body in
            try body.setVelocity(Vector(x: .greatestFiniteMagnitude, y: .greatestFiniteMagnitude))
        }
        let clamped = try ContinuousCollisionPlanner.plan(
            for: world,
            gravity: .zero,
            timeStep: 1,
            configuration: ContinuousCollisionConfiguration(
                maximumMotionPerSubstep: 1,
                maximumSubsteps: 4
            )
        )
        #expect(clamped.substepCount == 4)
        #expect(clamped.maximumPredictedMotion == .greatestFiniteMagnitude)
        #expect(clamped.isClamped)
    }

    @Test("Reference substeps prevent a fast circle from crossing a thin wall")
    func referenceTunnelingBound() throws {
        var discreteWorld = try tunnelingWorld()
        var discreteTracker = CollisionTracker()
        var discreteSolver = CollisionSolverState()
        var discreteSleeping = SleepingState()
        let discrete = try ReferencePhysics.stepWithEvents(
            world: &discreteWorld,
            collisionTracker: &discreteTracker,
            collisionSolverState: &discreteSolver,
            sleepingState: &discreteSleeping,
            gravity: .zero,
            timeStep: 1
        )
        #expect(discrete.world.bodies[0].position.x == 20)
        #expect(discrete.collisionEvents.isEmpty)
        #expect(discrete.continuousCollisionPlans[0].substepCount == 1)

        var boundedWorld = try tunnelingWorld()
        var boundedTracker = CollisionTracker()
        var boundedSolver = CollisionSolverState()
        var boundedSleeping = SleepingState()
        let bounded = try ReferencePhysics.stepWithEvents(
            world: &boundedWorld,
            collisionTracker: &boundedTracker,
            collisionSolverState: &boundedSolver,
            sleepingState: &boundedSleeping,
            gravity: .zero,
            timeStep: 1,
            continuousCollision: ContinuousCollisionConfiguration(
                maximumMotionPerSubstep: 1,
                maximumSubsteps: 32
            )
        )
        #expect(bounded.continuousCollisionPlans[0].substepCount == 20)
        #expect(!bounded.continuousCollisionPlans[0].isClamped)
        #expect(bounded.world.bodies[0].position.x < 10)
        #expect(bounded.world.bodies[0].velocity.x < 0)
        #expect(bounded.collisionEvents.map(\.phase).contains(.started))
        #expect(bounded.collisionEvents.map(\.phase).contains(.ended))
    }

    @Test("Accumulated force is preserved across every adaptive substep")
    func forcePreservation() throws {
        var world = World()
        let body = try world.add(Bodies.circle(at: .zero, radius: 1))
        try world.applyForce(Vector(x: 10, y: 0), to: body)
        var tracker = CollisionTracker()
        var solverState = CollisionSolverState()
        var sleepingState = SleepingState()
        let result = try ReferencePhysics.stepWithEvents(
            world: &world,
            collisionTracker: &tracker,
            collisionSolverState: &solverState,
            sleepingState: &sleepingState,
            gravity: .zero,
            timeStep: 1,
            continuousCollision: ContinuousCollisionConfiguration(
                maximumMotionPerSubstep: 1,
                maximumSubsteps: 16
            )
        )
        let finalBody = try #require(result.world.body(withID: body))
        #expect(result.continuousCollisionPlans[0].substepCount == 10)
        #expect(abs(finalBody.velocity.x - 10) < 0.000_1)
        #expect(finalBody.position.x > 5)
        #expect(finalBody.force == .zero)
    }

    #if canImport(Metal)
        @Test("Metal engine follows the same bounded-substep plan")
        func engine() async throws {
            guard MetalBackend.isAvailable else { return }
            #expect(throws: MatterError.invalidContinuousCollisionConfiguration) {
                try Engine(
                    continuousCollisionConfiguration: ContinuousCollisionConfiguration(
                        maximumSubsteps: 0
                    )
                )
            }

            let engine = try Engine(
                world: try tunnelingWorld(),
                gravity: .zero,
                fixedTimeStep: 1,
                continuousCollisionConfiguration: ContinuousCollisionConfiguration(
                    maximumMotionPerSubstep: 1,
                    maximumSubsteps: 32
                )
            )
            let result = try await engine.stepWithEvents()
            #expect(result.continuousCollisionPlans[0].substepCount == 20)
            #expect(result.world.bodies[0].velocity.x < 0)

            let runnerEngine = try Engine(
                gravity: .zero,
                fixedTimeStep: 0.1,
                continuousCollisionConfiguration: .standard
            )
            let runner = try Runner(engine: runnerEngine)
            let update = try await runner.advance(by: 0.1)
            #expect(update.continuousCollisionPlans.count == 1)
            #expect(update.continuousCollisionPlans[0].substepCount == 1)
        }
    #endif
}

private func tunnelingWorld() throws -> World {
    let material = BodyMaterial(
        restitution: 1,
        friction: 0,
        staticFriction: 0,
        airFriction: 0,
        slop: 0
    )
    var world = World()
    _ = try world.add(
        BodyDefinition(
            shape: .circle(radius: 1),
            position: .zero,
            velocity: Vector(x: 20, y: 0),
            material: material
        )
    )
    _ = try world.add(
        BodyDefinition(
            shape: .rectangle(width: 2, height: 20),
            position: Vector(x: 10, y: 0),
            isStatic: true,
            material: material
        )
    )
    return world
}
