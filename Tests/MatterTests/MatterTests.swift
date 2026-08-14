import Matter
import Testing

@Suite("Matter physics")
struct MatterTests {
    @Test("Vector arithmetic and normalization preserve expected values")
    func vectorArithmetic() {
        // Arrange
        let first = Vector(x: 3, y: 4)
        let second = Vector(x: 1, y: -2)

        // Act
        let sum = first + second
        let unit = first.normalized()

        // Assert
        #expect(sum == Vector(x: 4, y: 2))
        #expect(first.dot(second) == -5)
        #expect(first.length == 5)
        #expect(unit.x == 0.6)
        #expect(unit.y == 0.8)
    }

    @Test("Bodies factories retain geometry and simulation options")
    func bodyFactories() throws {
        // Arrange and act
        let circle = try Bodies.circle(
            at: Vector(x: 10, y: 20),
            radius: 5,
            velocity: Vector(x: 1, y: 2),
            mass: 3
        )
        let rectangle = try Bodies.rectangle(
            at: .zero,
            width: 8,
            height: 4,
            isStatic: true
        )

        // Assert
        #expect(circle.shape == .circle(radius: 5))
        #expect(circle.position == Vector(x: 10, y: 20))
        #expect(circle.mass == 3)
        #expect(rectangle.shape == .rectangle(width: 8, height: 4))
        #expect(rectangle.isStatic)
    }

    @Test("A world consumes force using deterministic semi-implicit Euler integration")
    func deterministicReferenceStep() throws {
        // Arrange
        var world = World()
        let identifier = try world.add(
            Bodies.circle(at: .zero, radius: 1, mass: 2)
        )
        try world.applyForce(Vector(x: 4, y: 0), to: identifier)

        // Act
        try ReferenceIntegrator.step(
            world: &world,
            gravity: Vector(x: 0, y: 10),
            timeStep: 0.5
        )
        let body = try #require(world.body(withID: identifier))

        // Assert
        #expect(body.velocity == Vector(x: 1, y: 5))
        #expect(body.position == Vector(x: 0.5, y: 2.5))
        #expect(body.force == .zero)
    }

    @Test("Static bodies ignore force and remain in place")
    func staticBodyDoesNotIntegrate() throws {
        // Arrange
        var world = World()
        let identifier = try world.add(
            Bodies.rectangle(at: Vector(x: 1, y: 2), width: 4, height: 4, isStatic: true)
        )
        try world.applyForce(Vector(x: 10, y: 10), to: identifier)

        // Act
        try ReferenceIntegrator.step(world: &world, gravity: Vector(x: 0, y: 9.81), timeStep: 1)
        let body = try #require(world.body(withID: identifier))

        // Assert
        #expect(body.position == Vector(x: 1, y: 2))
        #expect(body.velocity == .zero)
    }

    #if canImport(Metal)
    @Test("Metal integration advances a body when a system device is available")
    func metalIntegration() async throws {
        // Arrange
        guard MetalBackend.isAvailable else { return }
        let engine = try Engine(
            gravity: Vector(x: 0, y: 10),
            fixedTimeStep: 0.5
        )
        let definition = try Bodies.circle(at: .zero, radius: 1, mass: 2)
        let identifier = try await engine.add(definition)
        try await engine.applyForce(Vector(x: 4, y: 0), to: identifier)

        // Act
        let output = try await engine.step()
        let body = try #require(output.bodies.first { $0.id == identifier })

        // Assert
        #expect(body.velocity == Vector(x: 1, y: 5))
        #expect(body.position == Vector(x: 0.5, y: 2.5))
        #expect(body.force == .zero)
    }
    #endif
}
