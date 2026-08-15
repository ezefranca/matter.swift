import Foundation
import Testing

@testable import Matter

@Suite("Matter renderer-neutral drawing adapters")
struct MatterDrawingTests {
    @Test("Debug commands preserve geometry, semantic layers, and source identity")
    func debugCommands() throws {
        var world = World()
        let circle = try world.add(Bodies.circle(at: .zero, radius: 2))
        let rectangle = try world.add(
            Bodies.rectangle(at: Vector(x: 3, y: 0), width: 2, height: 4)
        )
        let compound = try world.add(
            BodyDefinition(
                shape: .compound(parts: [
                    try CompoundPart(shape: .circle(radius: 1), position: Vector(x: -2, y: 0)),
                    try CompoundPart(
                        shape: .rectangle(width: 2, height: 2),
                        position: Vector(x: 2, y: 0)
                    ),
                ]),
                position: Vector(x: 20, y: 0)
            )
        )
        let constraint = try world.addConstraint(
            ConstraintDefinition(
                first: .fixed(Vector(x: 0, y: -5)),
                second: .body(rectangle, local: Vector(x: 1, y: 0))
            )
        )
        let collisions = CollisionDetector.collisions(in: world)
        let collision = try #require(collisions.first)
        let commands = try MatterDrawingAdapter.commands(
            for: world,
            collisions: collisions,
            options: .debug
        )

        #expect(
            MatterDrawingLayer.allCases == [
                .bodies, .vertices, .constraints, .contacts, .bounds,
            ]
        )
        #expect(commands.filter { $0.layer == .bodies }.count == 4)
        #expect(commands.filter { $0.layer == .vertices }.count == 8)
        #expect(commands.filter { $0.layer == .constraints }.count == 1)
        #expect(commands.filter { $0.layer == .contacts }.count == collision.contacts.count * 2)
        #expect(commands.filter { $0.layer == .bounds }.count == 3)

        #expect(commands[0].source == .body(circle))
        #expect(commands[0].primitive == .circle(center: .zero, radius: 2))
        #expect(commands[1].source == .body(rectangle))
        #expect(commands[2].source == .body(compound))
        #expect(commands[3].source == .body(compound))

        let constraintCommand = try #require(
            commands.first { $0.source == .constraint(constraint) }
        )
        #expect(
            constraintCommand.primitive
                == .segment(
                    start: Vector(x: 0, y: -5),
                    end: Vector(x: 4, y: 0)
                )
        )
        let contactCommand = try #require(commands.first { $0.layer == .contacts })
        #expect(contactCommand.source == .collision(collision.pair))
        let boundsCommand = try #require(
            commands.first { $0.layer == .bounds && $0.source == .body(circle) }
        )
        #expect(
            boundsCommand.primitive
                == .bounds(
                    Bounds(
                        minimum: Vector(x: -2, y: -2),
                        maximum: Vector(x: 2, y: 2)
                    )
                )
        )

        let data = try JSONEncoder().encode(commands)
        #expect(try JSONDecoder().decode([MatterDrawingCommand].self, from: data) == commands)
    }

    @Test("Layer options support standard, empty, individual, and serialized forms")
    func layerOptions() throws {
        var world = World()
        _ = try world.add(Bodies.circle(at: .zero, radius: 1))

        let standard = try MatterDrawingAdapter.commands(for: world)
        #expect(standard.map(\.layer) == [.bodies])
        #expect(try MatterDrawingAdapter.commands(for: world, options: []).isEmpty)
        #expect(
            try MatterDrawingAdapter.commands(for: world, options: .vertices).isEmpty
        )
        #expect(
            try MatterDrawingAdapter.commands(for: world, options: .contacts).isEmpty
        )
        #expect(
            try MatterDrawingAdapter.commands(for: world, options: .bounds).map(\.layer)
                == [.bounds]
        )
        let custom = MatterDrawingOptions(rawValue: MatterDrawingOptions.debug.rawValue)
        let data = try JSONEncoder().encode(custom)
        #expect(try JSONDecoder().decode(MatterDrawingOptions.self, from: data) == .debug)
        #expect(MatterDrawingOptions.standard == [.bodies, .constraints])
    }

    @Test("Missing decoded constraint bodies fail without partial output")
    func corruptConstraintReference() throws {
        var world = World()
        let identifier = try world.add(Bodies.circle(at: .zero, radius: 1))
        _ = try world.addConstraint(
            ConstraintDefinition(first: .fixed(.zero), second: .body(identifier))
        )
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(world))
                as? [String: Any]
        )
        object["bodies"] = []
        let corrupt = try JSONDecoder().decode(
            World.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        #expect(throws: MatterError.unknownBody(identifier)) {
            try MatterDrawingAdapter.commands(for: corrupt, options: .constraints)
        }
    }
}
