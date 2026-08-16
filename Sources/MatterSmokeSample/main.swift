import Foundation
import Matter

@main
struct MatterSmokeSample {
    static func main() async throws {
        let engine = try Engine(gravity: Vector(x: 0, y: 9.81))
        let ball = try await engine.add(
            Bodies.circle(at: Vector(x: 0, y: -10), radius: 1, mass: 1)
        )
        try await engine.applyForce(Vector(x: 2, y: 0), to: ball)
        let result = try await engine.step()
        guard let body = result.body(withID: ball) else {
            throw SmokeSampleError.missingBody
        }
        print("Matter stepped body \(ball.rawValue) to (\(body.position.x), \(body.position.y)).")
        if ProcessInfo.processInfo.environment["SWIFT_PACKAGE_INSTRUMENTS_HOLD"] == "1" {
            try await Task.sleep(for: .seconds(20))
        }
    }
}

private enum SmokeSampleError: Error {
    case missingBody
}
