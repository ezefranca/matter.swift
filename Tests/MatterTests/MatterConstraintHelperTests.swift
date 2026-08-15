import Foundation
import Testing

@testable import Matter

@Suite("Matter constraint construction helpers")
struct MatterConstraintHelperTests {
    @Test("Chains, pendulums, and bridges produce deterministic definitions")
    func linearHelpers() throws {
        let bodies = [BodyID(rawValue: 1), BodyID(rawValue: 2), BodyID(rawValue: 3)]
        let chain = try Constraints.chain(
            bodies,
            length: 2,
            stiffness: 0.7,
            damping: 0.2,
            angularStiffness: 0.1,
            maximumImpulse: 4
        )
        #expect(chain.count == 2)
        #expect(chain.allSatisfy { $0.label == "Chain" })
        #expect(chain[0].first == .body(bodies[0]))
        #expect(chain[0].second == .body(bodies[1]))
        #expect(chain[1].second == .body(bodies[2]))
        #expect(chain[0].angularStiffness == 0.1)

        let pendulum = try Constraints.pendulum(
            bodies[0],
            pivot: Vector(x: 5, y: 6),
            length: 10
        )
        #expect(pendulum.label == "Pendulum")
        #expect(pendulum.first == .fixed(Vector(x: 5, y: 6)))

        let bridge = try Constraints.bridge(
            bodies,
            from: .zero,
            to: Vector(x: 10, y: 0),
            segmentLength: 5
        )
        #expect(bridge.count == 4)
        #expect(bridge.suffix(2).allSatisfy { $0.label == "Bridge Anchor" })
        #expect(bridge[2].second == .body(bodies[0]))
        #expect(bridge[3].second == .body(bodies[2]))

        #expect(throws: MatterError.invalidConstraint) {
            try Constraints.chain([bodies[0]])
        }
        #expect(throws: MatterError.invalidConstraint) {
            try Constraints.bridge([bodies[0]], from: .zero, to: .zero)
        }
    }

    @Test("Mesh and soft-body helpers cover rows, columns, and cross braces")
    func gridHelpers() throws {
        let grid = [
            [BodyID(rawValue: 1), BodyID(rawValue: 2)],
            [BodyID(rawValue: 3), BodyID(rawValue: 4)],
        ]
        let mesh = try Constraints.mesh(grid)
        #expect(mesh.count == 6)
        #expect(mesh.allSatisfy { $0.label == "Mesh" })

        let unbraced = try Constraints.mesh(grid, crossBrace: false)
        #expect(unbraced.count == 4)
        let singleRow = try Constraints.mesh([grid[0]])
        #expect(singleRow.count == 1)
        let singleColumn = try Constraints.mesh([[grid[0][0]], [grid[1][0]]])
        #expect(singleColumn.count == 1)

        let softBody = try Constraints.softBody(grid)
        #expect(softBody.count == 6)
        #expect(softBody.allSatisfy { $0.label == "Soft Body" })
        #expect(softBody[0].stiffness == 0.5)
        #expect(softBody[0].damping == 0.15)

        #expect(throws: MatterError.invalidConstraint) {
            try Constraints.mesh([])
        }
        #expect(throws: MatterError.invalidConstraint) {
            try Constraints.mesh([[]])
        }
        #expect(throws: MatterError.invalidConstraint) {
            try Constraints.mesh([grid[0], [grid[1][0]]])
        }
    }

    @Test("World adds constraint batches atomically and captures rest state")
    func worldBatchInsertion() throws {
        var world = World()
        let composite = try world.addComposite(label: "Assembly")
        let bodies = try world.add([
            Bodies.circle(at: .zero, radius: 1),
            Bodies.circle(at: Vector(x: 2, y: 0), radius: 1),
            Bodies.circle(at: Vector(x: 5, y: 0), radius: 1),
        ])
        let definitions = try Constraints.chain(bodies)
        let identifiers = try world.addConstraints(definitions, to: composite)

        #expect(identifiers.count == 2)
        #expect(world.constraints.map(\.length) == [2, 3])
        #expect(world.composite(withID: composite)?.constraintIDs == identifiers)
        #expect(try world.addConstraints([], to: composite).isEmpty)

        let beforeFailure = world
        var invalid = definitions[0]
        invalid.stiffness = -1
        #expect(throws: MatterError.invalidConstraint) {
            try world.addConstraints([definitions[0], invalid], to: composite)
        }
        #expect(world == beforeFailure)

        let missing = BodyID(rawValue: 999)
        #expect(throws: MatterError.unknownBody(missing)) {
            try world.addConstraints(
                [
                    definitions[0],
                    ConstraintDefinition(first: .fixed(.zero), second: .body(missing)),
                ]
            )
        }
        #expect(world == beforeFailure)
        #expect(throws: MatterError.unknownComposite(CompositeID(rawValue: 999))) {
            try world.addConstraints(definitions, to: CompositeID(rawValue: 999))
        }
    }

    @Test("Constraint batch identifier exhaustion is atomic")
    func batchExhaustion() throws {
        var world = World()
        let body = try world.add(Bodies.circle(at: .zero, radius: 1))
        let encoded = String(decoding: try JSONEncoder().encode(world), as: UTF8.self)
        let exhaustedJSON = encoded.replacingOccurrences(
            of: #""nextConstraintIdentifier":0"#,
            with: #""nextConstraintIdentifier":18446744073709551615"#
        )
        var exhausted = try JSONDecoder().decode(World.self, from: Data(exhaustedJSON.utf8))
        let definition = try Constraints.pin(body, to: .zero)

        #expect(throws: MatterError.constraintIdentifierExhausted) {
            try exhausted.addConstraints([definition])
        }
        #expect(exhausted.constraints.isEmpty)
        #expect(try exhausted.addConstraints([]).isEmpty)
    }

    #if canImport(Metal)
        @Test("Engine inserts a complete constraint assembly in one actor hop")
        func engineBatchInsertion() async throws {
            guard MetalBackend.isAvailable else { return }
            let engine = try Engine(gravity: .zero)
            let bodies = try await engine.add([
                Bodies.circle(at: .zero, radius: 1),
                Bodies.circle(at: Vector(x: 2, y: 0), radius: 1),
                Bodies.circle(at: Vector(x: 4, y: 0), radius: 1),
            ])
            let composite = try await engine.addComposite(label: "Chain")
            let constraints = try await engine.addConstraints(
                Constraints.chain(bodies),
                to: composite
            )

            #expect(constraints.count == 2)
            #expect(await engine.snapshot().constraints.map(\.id) == constraints)
        }
    #endif
}
