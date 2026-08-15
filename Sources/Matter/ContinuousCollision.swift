import Foundation

/// Motion bounds for deterministic adaptive collision substeps.
@frozen
public struct ContinuousCollisionConfiguration: Sendable, Hashable, Codable {
    /// Whether adaptive substeps are enabled.
    public var enabled: Bool

    /// Maximum predicted surface motion allowed in one unclamped substep.
    public var maximumMotionPerSubstep: Float

    /// Maximum integration and solve passes allowed for one fixed tick.
    public var maximumSubsteps: Int

    /// Creates configuration validated by a planner, engine, or reference tick.
    public init(
        enabled: Bool = true,
        maximumMotionPerSubstep: Float = 1,
        maximumSubsteps: Int = 16
    ) {
        self.enabled = enabled
        self.maximumMotionPerSubstep = maximumMotionPerSubstep
        self.maximumSubsteps = maximumSubsteps
    }

    /// Stable bounded-motion defaults for worlds that opt into substepping.
    public static let standard = Self()

    /// One discrete integration and solve pass per fixed tick.
    public static let disabled = Self(enabled: false)

    func validate() throws {
        guard
            maximumMotionPerSubstep.isFinite,
            maximumMotionPerSubstep > 0,
            maximumSubsteps > 0
        else {
            throw MatterError.invalidContinuousCollisionConfiguration
        }
    }
}

/// The immutable adaptive-substep decision for one fixed tick.
@frozen
public struct ContinuousCollisionPlan: Sendable, Hashable, Codable {
    /// Integration and solve passes selected for the fixed tick.
    public let substepCount: Int

    /// Duration of each selected substep.
    public let substepTime: Float

    /// Largest conservative body-surface motion predicted for the fixed tick.
    public let maximumPredictedMotion: Float

    /// Whether the requested motion bound required more than the configured cap.
    public let isClamped: Bool

    init(
        substepCount: Int,
        substepTime: Float,
        maximumPredictedMotion: Float,
        isClamped: Bool
    ) {
        self.substepCount = substepCount
        self.substepTime = substepTime
        self.maximumPredictedMotion = maximumPredictedMotion
        self.isClamped = isClamped
    }
}

/// Plans deterministic substeps that explicitly bound predicted surface motion.
@frozen
public enum ContinuousCollisionPlanner {
    /// Returns the adaptive plan for a world snapshot and fixed time step.
    ///
    /// Linear velocity and acceleration contribute conservative translation.
    /// Angular velocity and torque contribute arc motion at the body's current
    /// bounding radius. Static and sleeping bodies contribute no motion.
    public static func plan(
        for world: World,
        gravity: Vector,
        timeStep: Float,
        configuration: ContinuousCollisionConfiguration = .standard
    ) throws -> ContinuousCollisionPlan {
        guard timeStep.isFinite, timeStep > 0 else { throw MatterError.invalidTimeStep }
        guard gravity.isFinite else { throw MatterError.invalidVector }
        try configuration.validate()

        let maximumMotion = world.bodies.reduce(Float.zero) { current, body in
            max(current, predictedMotion(of: body, gravity: gravity, timeStep: timeStep))
        }
        guard configuration.enabled else {
            return ContinuousCollisionPlan(
                substepCount: 1,
                substepTime: timeStep,
                maximumPredictedMotion: maximumMotion,
                isClamped: false
            )
        }

        let ratio = maximumMotion / configuration.maximumMotionPerSubstep
        let isClamped = !ratio.isFinite || ratio > Float(configuration.maximumSubsteps)
        let substepCount: Int
        if ratio <= 1 {
            substepCount = 1
        } else if isClamped {
            substepCount = configuration.maximumSubsteps
        } else {
            substepCount = Int(ceil(ratio))
        }
        return ContinuousCollisionPlan(
            substepCount: substepCount,
            substepTime: timeStep / Float(substepCount),
            maximumPredictedMotion: maximumMotion,
            isClamped: isClamped
        )
    }
}

private extension ContinuousCollisionPlanner {
    static func predictedMotion(of body: Body, gravity: Vector, timeStep: Float) -> Float {
        guard !body.isStatic, !body.isSleeping else { return 0 }
        let acceleration = gravity + body.force * body.inverseMass
        let finalVelocity = body.velocity + acceleration * timeStep
        let translation = max(body.velocity.length, finalVelocity.length) * timeStep
        let finalAngularVelocity =
            body.angularVelocity + body.torque * body.inverseInertia * timeStep
        let angularMotion =
            max(abs(body.angularVelocity), abs(finalAngularVelocity))
            * timeStep * boundingRadius(of: body)
        let motion = translation + angularMotion
        return motion.isFinite ? motion : .greatestFiniteMagnitude
    }

    static func boundingRadius(of body: Body) -> Float {
        let halfWidth = body.bounds.width / 2
        let halfHeight = body.bounds.height / 2
        return (halfWidth * halfWidth + halfHeight * halfHeight).squareRoot()
    }
}
