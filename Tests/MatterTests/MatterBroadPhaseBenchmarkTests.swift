import Foundation
import Testing

@testable import Matter

@Suite("Matter broad-phase scaling benchmarks")
struct MatterBroadPhaseBenchmarkTests {
    @Test("Sparse horizontal and vertical worlds require linear primary-axis work")
    func sparseScaling() throws {
        let bodyCount = 2_048
        var horizontal = World()
        var vertical = World()
        for index in 0..<bodyCount {
            let coordinate = Float(index * 2)
            _ = try horizontal.add(
                Bodies.circle(at: Vector(x: coordinate, y: 0), radius: 0.5)
            )
            _ = try vertical.add(
                Bodies.circle(at: Vector(x: 0, y: coordinate), radius: 0.5)
            )
        }

        let horizontalResult = SweepAndPruneBroadPhase.query(in: horizontal)
        let verticalResult = SweepAndPruneBroadPhase.query(in: vertical)
        for result in [horizontalResult, verticalResult] {
            #expect(result.metrics.bodyCount == bodyCount)
            #expect(result.metrics.primaryAxisTests == bodyCount - 1)
            #expect(result.metrics.boundsTests == 0)
            #expect(result.metrics.collisionFilterTests == 0)
            #expect(result.metrics.candidateCount == 0)
            #expect(result.pairs.isEmpty)
        }
        #expect(horizontalResult.metrics.axis == .horizontal)
        #expect(verticalResult.metrics.axis == .vertical)
    }

    @Test("Fully overlapping bounds expose the exact output-sized worst case")
    func denseWorstCase() throws {
        let bodyCount = 128
        var world = World()
        for _ in 0..<bodyCount {
            _ = try world.add(Bodies.circle(at: .zero, radius: 1))
        }

        let result = SweepAndPruneBroadPhase.query(in: world)
        let expectedPairs = bodyCount * (bodyCount - 1) / 2
        #expect(result.metrics.axis == .horizontal)
        #expect(result.metrics.primaryAxisTests == expectedPairs)
        #expect(result.metrics.boundsTests == expectedPairs)
        #expect(result.metrics.collisionFilterTests == expectedPairs)
        #expect(result.metrics.candidateCount == expectedPairs)
        #expect(result.pairs.count == expectedPairs)
        #expect(result.pairs == result.pairs.sorted())
        #expect(CollisionDetector.potentialPairs(in: world) == result.pairs)
    }

    @Test("Adaptive candidates match an exhaustive deterministic oracle")
    func exhaustiveParity() throws {
        var world = World()
        var generator = Generator(state: 0x5EED)
        for index in 0..<300 {
            let category: UInt32 = index.isMultiple(of: 5) ? 0b10 : 0b1
            let mask: UInt32 = index.isMultiple(of: 7) ? category : UInt32.max
            _ = try world.add(
                BodyDefinition(
                    shape: .rectangle(
                        width: generator.next(in: 0.5...4),
                        height: generator.next(in: 0.5...4)
                    ),
                    position: Vector(
                        x: generator.next(in: -100...100),
                        y: generator.next(in: -100...100)
                    ),
                    angle: generator.next(in: -.pi ... .pi),
                    collisionFilter: CollisionFilter(category: category, mask: mask)
                )
            )
        }

        let result = SweepAndPruneBroadPhase.query(in: world)
        var exhaustive: [BodyPair] = []
        for firstIndex in world.bodies.indices {
            for secondIndex in world.bodies.indices where secondIndex > firstIndex {
                let first = world.bodies[firstIndex]
                let second = world.bodies[secondIndex]
                guard
                    first.bounds.overlaps(second.bounds),
                    first.collisionFilter.allowsCollision(with: second.collisionFilter),
                    let pair = BodyPair(first.id, second.id)
                else { continue }
                exhaustive.append(pair)
            }
        }
        #expect(result.pairs == exhaustive.sorted())
        #expect(result.metrics.candidateCount == exhaustive.count)
        #expect(result.metrics.primaryAxisTests < 10_000)
    }

    @Test("Metrics are public value snapshots and collision lookup ignores stale pairs")
    func valueSemanticsAndLookup() throws {
        let empty = SweepAndPruneBroadPhase.query(in: World())
        #expect(empty.metrics.axis == .horizontal)
        #expect(empty.metrics.bodyCount == 0)
        #expect(BroadPhaseAxis.allCases == [.horizontal, .vertical])

        var world = World()
        let first = try world.add(Bodies.circle(at: .zero, radius: 1))
        let second = try world.add(Bodies.circle(at: Vector(x: 1, y: 0), radius: 1))
        let result = SweepAndPruneBroadPhase.query(in: world)
        let data = try JSONEncoder().encode(result)
        #expect(try JSONDecoder().decode(BroadPhaseResult.self, from: data) == result)

        let stale = try #require(BodyPair(first, BodyID(rawValue: 999)))
        let collisions = CollisionDetector.collisions(
            in: world,
            potentialPairs: [try #require(BodyPair(first, second)), stale]
        )
        #expect(collisions.count == 1)
        #expect(collisions[0].pair == BodyPair(first, second))
    }
}

private struct Generator {
    var state: UInt64

    mutating func next(in range: ClosedRange<Float>) -> Float {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let unit = Float(state >> 40) / Float(1 << 24)
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }
}
