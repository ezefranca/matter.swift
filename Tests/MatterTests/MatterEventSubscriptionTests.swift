import Foundation
import Testing

@testable import Matter

@Suite("Matter typed event subscriptions")
struct MatterEventSubscriptionTests {
    @Test("Newest buffering publishes complete immutable results and cancellation finishes")
    func newestBuffering() async throws {
        guard MetalBackend.isAvailable else { return }
        let (engine, body) = try await makeEngine()
        let subscription = try await Events.subscribe(to: engine)
        #expect(await engine.eventSubscriptionCount() == 1)

        let first = try await engine.stepWithEvents()
        let second = try await engine.stepWithEvents()
        var iterator = subscription.stream.makeAsyncIterator()
        let delivered = await iterator.next()
        #expect(delivered == second)
        #expect(delivered != first)
        #expect(delivered?.world.body(withID: body)?.position.x == 3)

        await subscription.cancel()
        await subscription.cancel()
        #expect(await engine.eventSubscriptionCount() == 0)
        #expect(await iterator.next() == nil)
    }

    @Test("Oldest and unbounded buffering preserve their documented order")
    func bufferingOrder() async throws {
        guard MetalBackend.isAvailable else { return }
        let (oldestEngine, _) = try await makeEngine()
        let oldest = try await Events.subscribe(
            to: oldestEngine,
            bufferingPolicy: .bufferingOldest(1)
        )
        let oldestFirst = try await oldestEngine.stepWithEvents()
        _ = try await oldestEngine.stepWithEvents()
        var oldestIterator = oldest.stream.makeAsyncIterator()
        #expect(await oldestIterator.next() == oldestFirst)
        await oldest.cancel()

        let (unboundedEngine, _) = try await makeEngine()
        let unbounded = try await Events.subscribe(
            to: unboundedEngine,
            bufferingPolicy: .unbounded
        )
        let unboundedFirst = try await unboundedEngine.stepWithEvents()
        let unboundedSecond = try await unboundedEngine.stepWithEvents()
        var unboundedIterator = unbounded.stream.makeAsyncIterator()
        #expect(await unboundedIterator.next() == unboundedFirst)
        #expect(await unboundedIterator.next() == unboundedSecond)
        await unbounded.cancel()
    }

    @Test("Policies validate capacities and round-trip through Codable")
    func policyValidation() async throws {
        guard MetalBackend.isAvailable else { return }
        let (engine, _) = try await makeEngine()
        for policy in [
            MatterEventBufferingPolicy.bufferingNewest(0),
            .bufferingOldest(-1),
        ] {
            await #expect(throws: MatterError.invalidEventBufferCapacity) {
                try await Events.subscribe(to: engine, bufferingPolicy: policy)
            }
        }
        #expect(await engine.eventSubscriptionCount() == 0)

        let policies: [MatterEventBufferingPolicy] = [
            .unbounded, .bufferingNewest(2), .bufferingOldest(3),
        ]
        let data = try JSONEncoder().encode(policies)
        #expect(
            try JSONDecoder().decode([MatterEventBufferingPolicy].self, from: data)
                == policies
        )
    }

    @Test("Removing all subscriptions finishes each stream without affecting later subscribers")
    func removeAll() async throws {
        guard MetalBackend.isAvailable else { return }
        let (engine, _) = try await makeEngine()
        let first = try await Events.subscribe(to: engine, bufferingPolicy: .unbounded)
        let second = try await Events.subscribe(to: engine, bufferingPolicy: .unbounded)
        #expect(await engine.eventSubscriptionCount() == 2)

        await Events.removeAll(from: engine)
        #expect(await engine.eventSubscriptionCount() == 0)
        var firstIterator = first.stream.makeAsyncIterator()
        var secondIterator = second.stream.makeAsyncIterator()
        #expect(await firstIterator.next() == nil)
        #expect(await secondIterator.next() == nil)

        let replacement = try await Events.subscribe(to: engine)
        _ = try await engine.step()
        var replacementIterator = replacement.stream.makeAsyncIterator()
        #expect(await replacementIterator.next()?.tickCount == 1)
        await replacement.cancel()
    }

    @Test("Dropping a subscription releases its engine slot")
    func subscriptionLifetime() async throws {
        guard MetalBackend.isAvailable else { return }
        let (engine, _) = try await makeEngine()
        var subscription: MatterEventSubscription? = try await Events.subscribe(to: engine)
        #expect(subscription != nil)
        #expect(await engine.eventSubscriptionCount() == 1)

        subscription = nil
        for _ in 0..<100 where await engine.eventSubscriptionCount() != 0 {
            await Task.yield()
        }
        #expect(await engine.eventSubscriptionCount() == 0)
    }

    private func makeEngine() async throws -> (Engine, BodyID) {
        let engine = try Engine(
            gravity: Vector(x: 1, y: 0),
            fixedTimeStep: 1
        )
        let body = try await engine.add(
            BodyDefinition(
                shape: .circle(radius: 1),
                position: .zero,
                material: BodyMaterial(airFriction: 0)
            )
        )
        return (engine, body)
    }
}
