import Testing

@testable import Matter

@Suite("Matter collision events")
struct MatterCollisionEventTests {
    @Test("Tracker emits one stable start, active, and end event per pair")
    func collisionLifecycle() throws {
        let collision = try makeCollision()
        var tracker = CollisionTracker()

        #expect(tracker.activePairs.isEmpty)
        var events = tracker.update(with: [collision, collision])
        #expect(events.count == 1)
        #expect(events[0].phase == .started)
        #expect(events[0].pair == collision.pair)
        #expect(events[0].collision == collision)
        #expect(tracker.activePairs == [collision.pair])

        events = tracker.update(with: [collision])
        #expect(events.map(\.phase) == [.active])

        events = tracker.update(with: [])
        #expect(events.map(\.phase) == [.ended])
        #expect(events[0].collision == collision)
        #expect(tracker.update(with: []).isEmpty)

        _ = tracker.update(with: [collision])
        tracker.reset()
        #expect(tracker.activePairs.isEmpty)
        #expect(tracker.update(with: [collision]).first?.phase == .started)
        #expect(CollisionPhase.allCases.map(\.rawValue) == ["started", "active", "ended"])
    }

    @Test("Tracker orders current and ended pairs canonically")
    func collisionEventOrdering() throws {
        var world = World()
        _ = try world.add(Bodies.circle(at: .zero, radius: 2))
        _ = try world.add(Bodies.circle(at: Vector(x: 1, y: 0), radius: 2))
        _ = try world.add(Bodies.circle(at: Vector(x: 2, y: 0), radius: 2))
        let collisions = CollisionDetector.collisions(in: world)
        var tracker = CollisionTracker()

        let started = tracker.update(with: Array(collisions.reversed()))
        #expect(started.map(\.pair) == collisions.map(\.pair).sorted())

        let retained = try #require(collisions.last)
        let mixed = tracker.update(with: [retained])
        #expect(mixed.first?.phase == .active)
        #expect(mixed.dropFirst().allSatisfy { $0.phase == .ended })
        #expect(mixed.dropFirst().map(\.pair) == mixed.dropFirst().map(\.pair).sorted())
    }

    #if canImport(Metal)
        @Test("Engine accumulates per-tick events and reports removal as end")
        func engineCollisionEvents() async throws {
            guard MetalBackend.isAvailable else { return }
            let engine = try Engine(gravity: .zero, fixedTimeStep: 0.1)
            let first = try await engine.add(
                BodyDefinition(
                    shape: .circle(radius: 2),
                    position: .zero,
                    isStatic: true,
                    isSensor: true
                )
            )
            let second = try await engine.add(
                BodyDefinition(
                    shape: .circle(radius: 2),
                    position: Vector(x: 1, y: 0),
                    isStatic: true
                )
            )

            let result = try await engine.stepWithEvents(ticks: 2)
            #expect(result.tickCount == 2)
            #expect(result.world.bodyCount == 2)
            #expect(result.collisions.count == 1)
            #expect(result.collisionEvents.map(\.phase) == [.started, .active])
            #expect(result.collisionEvents.allSatisfy { $0.pair == BodyPair(first, second) })

            _ = await engine.removeBody(withID: second)
            let ended = try await engine.stepWithEvents()
            #expect(ended.collisions.isEmpty)
            #expect(ended.collisionEvents.map(\.phase) == [.ended])
        }
    #endif

    private func makeCollision() throws -> Collision {
        var world = World()
        _ = try world.add(Bodies.circle(at: .zero, radius: 2))
        _ = try world.add(Bodies.circle(at: Vector(x: 3, y: 0), radius: 2))
        return try #require(CollisionDetector.collisions(in: world).first)
    }
}
