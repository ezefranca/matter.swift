import Foundation
import Testing

@testable import Matter

@Suite("Matter composites and batch mutations")
struct MatterCompositeTests {
    private enum ExpectedFailure: Error {
        case stop
    }

    @Test("Composite identifiers and hierarchy preserve stable ordering")
    func hierarchyAndIdentifiers() throws {
        var world = World()
        let root = try world.addComposite(label: "Root", metadata: ["kind": "scene"])
        let child = try world.addComposite(label: "Child", parent: root)
        let grandchild = try world.addComposite(label: "Grandchild", parent: child)
        let otherRoot = try world.addComposite(label: "Other")

        #expect(root < child)
        #expect(CompositeID(rawValue: root.rawValue) == root)
        #expect(world.compositeCount == 4)
        #expect(world.composite(withID: root)?.metadata == ["kind": "scene"])
        #expect(world.childComposites().map(\.id) == [root, otherRoot])
        #expect(world.childComposites(of: root).map(\.id) == [child])

        try world.reparentComposite(grandchild, to: otherRoot)
        #expect(world.childComposites(of: otherRoot).map(\.id) == [grandchild])
        try world.reparentComposite(grandchild, to: nil)
        #expect(world.composite(withID: grandchild)?.parent == nil)

        #expect(throws: MatterError.compositeCycle) {
            try world.reparentComposite(root, to: root)
        }
        try world.reparentComposite(grandchild, to: child)
        #expect(throws: MatterError.compositeCycle) {
            try world.reparentComposite(root, to: grandchild)
        }
    }

    @Test("Membership moves between composites and recursive queries use world order")
    func membershipAndQueries() throws {
        var world = World()
        let root = try world.addComposite(label: "Root")
        let child = try world.addComposite(label: "Child", parent: root)
        let first = try world.add(Bodies.circle(at: .zero, radius: 1))
        let definitions = [
            try Bodies.circle(at: Vector(x: 2, y: 0), radius: 1),
            try Bodies.circle(at: Vector(x: 4, y: 0), radius: 1),
        ]
        let added = try world.add(definitions, to: child)
        #expect(try world.add([], to: root).isEmpty)

        try world.assignBody(first, to: root)
        try world.assignBody(first, to: root)
        #expect(world.composite(containing: first)?.id == root)
        #expect(world.composite(withID: root)?.bodyIDs == [first])
        #expect(try world.bodies(in: root).map(\.id) == [first] + added)
        #expect(try world.bodies(in: root, includingDescendants: false).map(\.id) == [first])

        try world.assignBody(first, to: child)
        #expect(world.composite(withID: root)?.bodyIDs.isEmpty == true)
        #expect(world.composite(withID: child)?.bodyIDs == added + [first])
        #expect(try world.unassignBody(first) == child)
        #expect(try world.unassignBody(first) == nil)
        #expect(world.composite(containing: first) == nil)
    }

    @Test("Batch updates and removals are atomic")
    func transactionalBatches() throws {
        var world = World()
        let composite = try world.addComposite()
        let identifiers = try world.add(
            [
                Bodies.circle(at: .zero, radius: 1),
                Bodies.circle(at: Vector(x: 2, y: 0), radius: 1),
            ],
            to: composite
        )
        let initial = world

        #expect(throws: MatterError.duplicateBody(identifiers[0])) {
            try world.updateBodies(withIDs: [identifiers[0], identifiers[0]]) { body in
                try body.translate(by: Vector(x: 1, y: 0))
            }
        }
        #expect(world == initial)

        let missing = BodyID(rawValue: 999)
        #expect(throws: MatterError.unknownBody(missing)) {
            try world.updateBodies(withIDs: [identifiers[0], missing]) { _ in }
        }
        #expect(throws: ExpectedFailure.stop) {
            try world.updateBodies(withIDs: identifiers) { body in
                try body.translate(by: Vector(x: 1, y: 0))
                throw ExpectedFailure.stop
            }
        }
        #expect(world == initial)

        try world.updateBodies(withIDs: identifiers) { body in
            try body.translate(by: Vector(x: 1, y: 2))
        }
        #expect(world.bodies.map(\.position) == [Vector(x: 1, y: 2), Vector(x: 3, y: 2)])
        try world.updateBodies(withIDs: []) { _ in throw ExpectedFailure.stop }

        let beforeInvalidRemoval = world
        #expect(throws: MatterError.duplicateBody(identifiers[1])) {
            try world.removeBodies(withIDs: [identifiers[1], identifiers[1]])
        }
        #expect(throws: MatterError.unknownBody(missing)) {
            try world.removeBodies(withIDs: [missing])
        }
        #expect(world == beforeInvalidRemoval)
        #expect(try world.removeBodies(withIDs: []).isEmpty)

        let removed = try world.removeBodies(withIDs: [identifiers[1], identifiers[0]])
        #expect(removed.map(\.id) == [identifiers[1], identifiers[0]])
        #expect(world.bodies.isEmpty)
        #expect(world.composite(withID: composite)?.bodyIDs.isEmpty == true)
    }

    @Test("Composite removal has explicit body ownership semantics")
    func removalSemantics() throws {
        var world = World()
        let root = try world.addComposite(label: "Root")
        let child = try world.addComposite(label: "Child", parent: root)
        let unassigned = try world.add(Bodies.circle(at: .zero, radius: 1))
        let assigned = try world.add([Bodies.circle(at: .zero, radius: 1)], to: child)[0]

        let removed = try world.removeComposite(withID: root)
        #expect(removed.map(\.id) == [root, child])
        #expect(world.composites.isEmpty)
        #expect(world.bodies.map(\.id) == [unassigned, assigned])

        let next = try world.addComposite(label: "Next")
        try world.assignBody(assigned, to: next)
        _ = try world.removeComposite(withID: next, removeBodies: true)
        #expect(world.bodies.map(\.id) == [unassigned])

        let retained = try world.addComposite(label: "Retained")
        try world.assignBody(unassigned, to: retained)
        world.removeAllComposites()
        #expect(world.bodies.map(\.id) == [unassigned])
        let monotonic = try world.addComposite()
        #expect(monotonic.rawValue > retained.rawValue)

        try world.assignBody(unassigned, to: monotonic)
        world.removeAllComposites(removeBodies: true, resetIdentifiers: true)
        #expect(world.bodies.isEmpty)
        #expect(try world.addComposite().rawValue == 1)
    }

    @Test("Body removal and clearing clean composite membership")
    func bodyCleanup() throws {
        var world = World()
        let composite = try world.addComposite()
        let first = try world.add([Bodies.circle(at: .zero, radius: 1)], to: composite)[0]
        #expect(world.removeBody(withID: first)?.id == first)
        #expect(world.composite(withID: composite)?.bodyIDs.isEmpty == true)

        _ = try world.add(
            [
                Bodies.circle(at: .zero, radius: 1),
                Bodies.circle(at: .zero, radius: 1),
            ],
            to: composite
        )
        world.removeAllBodies()
        #expect(world.composite(withID: composite)?.bodyIDs.isEmpty == true)
    }

    @Test("Composite and batch validation report precise failures")
    func validation() throws {
        var world = World()
        let missingComposite = CompositeID(rawValue: 999)
        let missingBody = BodyID(rawValue: 999)

        #expect(throws: MatterError.invalidLabel) {
            try world.addComposite(label: " bad")
        }
        #expect(throws: MatterError.invalidMetadata) {
            try world.addComposite(metadata: ["key": " bad"])
        }
        #expect(throws: MatterError.invalidMetadata) {
            try world.addComposite(metadata: ["": "value"])
        }
        #expect(throws: MatterError.unknownComposite(missingComposite)) {
            try world.addComposite(parent: missingComposite)
        }
        #expect(throws: MatterError.unknownComposite(missingComposite)) {
            try world.add([Bodies.circle(at: .zero, radius: 1)], to: missingComposite)
        }
        #expect(throws: MatterError.unknownComposite(missingComposite)) {
            try world.bodies(in: missingComposite)
        }
        #expect(throws: MatterError.unknownComposite(missingComposite)) {
            try world.reparentComposite(missingComposite, to: nil)
        }
        let composite = try world.addComposite()
        #expect(throws: MatterError.unknownComposite(missingComposite)) {
            try world.reparentComposite(composite, to: missingComposite)
        }
        #expect(throws: MatterError.unknownComposite(missingComposite)) {
            try world.removeComposite(withID: missingComposite)
        }
        #expect(throws: MatterError.unknownBody(missingBody)) {
            try world.assignBody(missingBody, to: composite)
        }
        let body = try world.add(Bodies.circle(at: .zero, radius: 1))
        #expect(throws: MatterError.unknownComposite(missingComposite)) {
            try world.assignBody(body, to: missingComposite)
        }
        #expect(throws: MatterError.unknownBody(missingBody)) {
            try world.unassignBody(missingBody)
        }
    }

    @Test("Composite state round-trips and exhausted identifiers cannot wrap")
    func codableAndExhaustion() throws {
        var world = World()
        let composite = try world.addComposite(label: "Root", metadata: ["key": "value"])
        let body = try world.add([Bodies.circle(at: .zero, radius: 1)], to: composite)[0]
        let data = try JSONEncoder().encode(world)
        let decoded = try JSONDecoder().decode(World.self, from: data)
        #expect(decoded == world)
        #expect(decoded.composite(containing: body)?.id == composite)

        let exhaustedComposite = Data(
            #"{"bodies":[],"composites":[],"constraints":[],"nextBodyIdentifier":0,"nextCompositeIdentifier":18446744073709551615,"nextConstraintIdentifier":0}"#
                .utf8
        )
        var noCompositeIdentifiers = try JSONDecoder().decode(World.self, from: exhaustedComposite)
        #expect(throws: MatterError.compositeIdentifierExhausted) {
            try noCompositeIdentifiers.addComposite()
        }

        let exhaustedBody = Data(
            #"{"bodies":[],"composites":[],"constraints":[],"nextBodyIdentifier":18446744073709551615,"nextCompositeIdentifier":0,"nextConstraintIdentifier":0}"#
                .utf8
        )
        var noBodyIdentifiers = try JSONDecoder().decode(World.self, from: exhaustedBody)
        #expect(throws: MatterError.bodyIdentifierExhausted) {
            try noBodyIdentifiers.add([Bodies.circle(at: .zero, radius: 1)])
        }
    }

    #if canImport(Metal)
        @Test("Engine exposes atomic body and composite mutations")
        func engineBatchSurface() async throws {
            guard MetalBackend.isAvailable else { return }
            let engine = try Engine(gravity: .zero)
            let composite = try await engine.addComposite(label: "Group")
            let identifiers = try await engine.add(
                [
                    Bodies.circle(at: .zero, radius: 1),
                    Bodies.circle(at: Vector(x: 2, y: 0), radius: 1),
                ],
                to: composite
            )
            try await engine.updateBodies(withIDs: identifiers) { body in
                try body.translate(by: Vector(x: 1, y: 0))
            }
            try await engine.assignBody(identifiers[0], to: composite)
            let child = try await engine.addComposite(parent: composite)
            try await engine.reparentComposite(child, to: nil)
            try await engine.updateWorld { world in
                try world.assignBody(identifiers[1], to: child)
            }

            #expect(await engine.snapshot().body(withID: identifiers[0])?.position.x == 1)
            #expect(try await engine.removeBodies(withIDs: [identifiers[0]]).count == 1)
            #expect(try await engine.removeComposite(withID: child).map(\.id) == [child])
        }
    #endif
}
