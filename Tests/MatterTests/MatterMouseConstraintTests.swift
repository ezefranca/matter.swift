import CoreGraphics
import Foundation
import Testing

@testable import Matter

@Suite("Matter pointer constraints")
struct MatterMouseConstraintTests {
    @Test("Configuration validates solver tuning and selection filters")
    func configurationValidation() throws {
        let standard = MouseConstraintConfiguration.standard
        #expect(standard.stiffness == 0.2)
        #expect(standard.damping == 0.1)
        #expect(standard.angularStiffness == 0)
        #expect(!standard.includesStaticBodies)

        for values in [
            (Float.nan, Float(0), Float(0)),
            (Float(0), Float.infinity, Float(0)),
            (Float(0), Float(0), Float(-1)),
            (Float(1.1), Float(0), Float(0)),
            (Float(0), Float(1.1), Float(0)),
            (Float(0), Float(0), Float(1.1)),
        ] {
            #expect(throws: MatterError.invalidConstraint) {
                try MouseConstraintConfiguration(
                    stiffness: values.0,
                    damping: values.1,
                    angularStiffness: values.2
                )
            }
        }
        #expect(throws: MatterError.invalidCollisionFilter) {
            try MouseConstraintConfiguration(
                collisionFilter: CollisionFilter(category: 0)
            )
        }

        var corrupted = standard
        corrupted.stiffness = .nan
        #expect(throws: MatterError.invalidConstraint) {
            try MouseConstraint(configuration: corrupted)
        }
        #expect(throws: MatterError.invalidVector) {
            try MouseConstraint(point: Vector(x: .infinity, y: 0))
        }
    }

    @Test("Press selects the last eligible body and preserves its local anchor")
    func pressSelectionAndAnchor() throws {
        var world = World()
        _ = try world.add(
            BodyDefinition(
                shape: .rectangle(width: 4, height: 4),
                position: .zero,
                isStatic: true
            )
        )
        let filtered = try world.add(
            BodyDefinition(
                shape: .rectangle(width: 4, height: 4),
                position: .zero,
                collisionFilter: CollisionFilter(category: 2, mask: 2)
            )
        )
        let selected = try world.add(
            BodyDefinition(
                shape: .rectangle(width: 4, height: 4),
                position: .zero,
                angle: .pi / 2,
                collisionFilter: CollisionFilter(category: 4, mask: 1)
            )
        )
        let configuration = try MouseConstraintConfiguration(
            stiffness: 0.4,
            damping: 0.3,
            angularStiffness: 0.2,
            collisionFilter: CollisionFilter(category: 1, mask: 4)
        )
        var mouse = try MouseConstraint(configuration: configuration)

        #expect(try mouse.press(at: Vector(x: 1, y: 0), in: &world) == selected)
        #expect(mouse.bodyID == selected)
        #expect(mouse.isActive)
        let constraint = try #require(mouse.constraintID.flatMap(world.constraint(withID:)))
        #expect(constraint.first == .fixed(Vector(x: 1, y: 0)))
        guard case let .body(anchorBody, localAnchor) = constraint.second else {
            Issue.record("Expected a body-local mouse anchor")
            return
        }
        #expect(anchorBody == selected)
        #expect(abs(localAnchor.x) < 0.000_01)
        #expect(abs(localAnchor.y + 1) < 0.000_01)
        #expect(constraint.length == 0)
        #expect(constraint.stiffness == 0.4)
        #expect(constraint.damping == 0.3)
        #expect(constraint.angularStiffness == 0.2)
        #expect(constraint.label == "Mouse Constraint")
        #expect(mouse.bodyID != filtered)
    }

    @Test("Static selection is explicit and empty presses end active drags")
    func staticAndEmptySelection() throws {
        var world = World()
        let fixed = try world.add(
            Bodies.rectangle(at: .zero, width: 4, height: 4, isStatic: true)
        )
        var mouse = try MouseConstraint()
        #expect(try mouse.press(at: .zero, in: &world) == nil)
        #expect(!mouse.isActive)

        mouse = try MouseConstraint(
            configuration: MouseConstraintConfiguration(includesStaticBodies: true)
        )
        #expect(try mouse.press(at: .zero, in: &world) == fixed)
        let previousConstraint = try #require(mouse.constraintID)
        #expect(world.constraintCount == 1)

        #expect(try mouse.press(at: Vector(x: 20, y: 20), in: &world) == nil)
        #expect(mouse.point == Vector(x: 20, y: 20))
        #expect(!mouse.isActive)
        #expect(world.constraint(withID: previousConstraint) == nil)
    }

    @Test("Moving and releasing update the transient world constraint")
    func moveAndRelease() throws {
        var world = World()
        let body = try world.add(Bodies.circle(at: .zero, radius: 2))
        var mouse = try MouseConstraint()

        try mouse.move(to: Vector(x: 5, y: 5), in: &world)
        #expect(mouse.point == Vector(x: 5, y: 5))
        #expect(throws: MatterError.invalidVector) {
            try mouse.move(to: Vector(x: .nan, y: 0), in: &world)
        }
        #expect(throws: MatterError.invalidVector) {
            try mouse.press(at: Vector(x: 0, y: .infinity), in: &world)
        }

        #expect(try mouse.press(at: .zero, in: &world) == body)
        let identifier = try #require(mouse.constraintID)
        try mouse.move(to: Vector(x: 4, y: 3), in: &world)
        #expect(mouse.point == Vector(x: 4, y: 3))
        #expect(world.constraint(withID: identifier)?.first == .fixed(Vector(x: 4, y: 3)))
        #expect(mouse.release(in: &world)?.id == identifier)
        #expect(!mouse.isActive)
        #expect(mouse.bodyID == nil)
        #expect(mouse.constraintID == nil)
        #expect(mouse.point == Vector(x: 4, y: 3))
        #expect(mouse.release(in: &world) == nil)
    }

    @Test("World fixed-point updates validate identifiers and endpoint kinds")
    func fixedPointUpdates() throws {
        var world = World()
        let first = try world.add(Bodies.circle(at: .zero, radius: 1))
        let second = try world.add(Bodies.circle(at: Vector(x: 3, y: 0), radius: 1))
        let fixedFirst = try world.addConstraint(Constraints.pin(first, to: .zero))
        let fixedSecond = try world.addConstraint(
            ConstraintDefinition(first: .body(first), second: .fixed(.zero))
        )
        let bodyPair = try world.addConstraint(Constraints.distance(between: first, and: second))

        try world.setFixedPoint(Vector(x: 1, y: 2), forConstraintWithID: fixedFirst)
        try world.setFixedPoint(Vector(x: 3, y: 4), forConstraintWithID: fixedSecond)
        #expect(world.constraint(withID: fixedFirst)?.first == .fixed(Vector(x: 1, y: 2)))
        #expect(world.constraint(withID: fixedSecond)?.second == .fixed(Vector(x: 3, y: 4)))
        #expect(throws: MatterError.invalidConstraint) {
            try world.setFixedPoint(.zero, forConstraintWithID: bodyPair)
        }
        #expect(throws: MatterError.unknownConstraint(ConstraintID(rawValue: 999))) {
            try world.setFixedPoint(.zero, forConstraintWithID: ConstraintID(rawValue: 999))
        }
        #expect(throws: MatterError.invalidVector) {
            try world.setFixedPoint(
                Vector(x: .nan, y: 0),
                forConstraintWithID: ConstraintID(rawValue: 999)
            )
        }
    }

    @Test("Externally removed drags report their stale identifier")
    func staleConstraint() throws {
        var world = World()
        _ = try world.add(Bodies.circle(at: .zero, radius: 1))
        var mouse = try MouseConstraint()
        _ = try mouse.press(at: .zero, in: &world)
        let identifier = try #require(mouse.constraintID)
        world.removeConstraint(withID: identifier)

        #expect(throws: MatterError.unknownConstraint(identifier)) {
            try mouse.move(to: Vector(x: 1, y: 0), in: &world)
        }
        #expect(mouse.point == .zero)
        #expect(mouse.release(in: &world) == nil)
    }

    @Test("Press insertion failure is transactional")
    func insertionFailure() throws {
        var ordinary = World()
        let body = try ordinary.add(Bodies.circle(at: .zero, radius: 1))
        let encoded = String(decoding: try JSONEncoder().encode(ordinary), as: UTF8.self)
        let exhaustedData = Data(
            encoded.replacingOccurrences(
                of: #""nextConstraintIdentifier":0"#,
                with: #""nextConstraintIdentifier":18446744073709551615"#
            ).utf8
        )
        var world = try JSONDecoder().decode(World.self, from: exhaustedData)
        var mouse = try MouseConstraint(point: Vector(x: 10, y: 10))

        #expect(throws: MatterError.constraintIdentifierExhausted) {
            try mouse.press(at: .zero, in: &world)
        }
        #expect(mouse.point == Vector(x: 10, y: 10))
        #expect(mouse.bodyID == nil)
        #expect(world.body(withID: body) != nil)
        #expect(world.constraintCount == 0)
    }

    @Test("Pointer state and native coordinates are value-semantic")
    func codableAndCoreGraphicsBridge() throws {
        let vector = try Vector(CGPoint(x: 12.5, y: -4.25))
        #expect(vector == Vector(x: 12.5, y: -4.25))
        #expect(vector.cgPoint == CGPoint(x: 12.5, y: -4.25))
        #expect(throws: MatterError.invalidVector) {
            try Vector(CGPoint(x: CGFloat.infinity, y: 0))
        }

        let configuration = try MouseConstraintConfiguration(includesStaticBodies: true)
        let mouse = try MouseConstraint(point: vector, configuration: configuration)
        let data = try JSONEncoder().encode(mouse)
        #expect(try JSONDecoder().decode(MouseConstraint.self, from: data) == mouse)
    }

    #if canImport(Metal)
        @Test("Engine transactions return updated pointer state")
        func engineTransaction() async throws {
            guard MetalBackend.isAvailable else { return }
            let engine = try Engine(gravity: .zero)
            let body = try await engine.add(Bodies.circle(at: .zero, radius: 2))
            let initial = try MouseConstraint()
            let pressed = try await engine.updateWorld { world in
                var mouse = initial
                _ = try mouse.press(at: .zero, in: &world)
                return mouse
            }
            #expect(pressed.bodyID == body)
            #expect(await engine.snapshot().constraintCount == 1)
        }
    #endif
}
