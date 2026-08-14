/// A two-dimensional vector used by Matter's physics state.
@frozen
public struct Vector: Sendable, Hashable, Codable {
    public var x: Float
    public var y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }

    public static let zero = Self(x: 0, y: 0)

    public var lengthSquared: Float {
        (x * x) + (y * y)
    }

    public var length: Float {
        lengthSquared.squareRoot()
    }

    public func dot(_ other: Self) -> Float {
        (x * other.x) + (y * other.y)
    }

    public func normalized() -> Self {
        let length = length
        guard length > 0 else { return .zero }
        return self / length
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public static prefix func - (value: Self) -> Self {
        Self(x: -value.x, y: -value.y)
    }

    public static func * (lhs: Self, rhs: Float) -> Self {
        Self(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    public static func * (lhs: Float, rhs: Self) -> Self {
        rhs * lhs
    }

    public static func / (lhs: Self, rhs: Float) -> Self {
        Self(x: lhs.x / rhs, y: lhs.y / rhs)
    }

    public static func += (lhs: inout Self, rhs: Self) {
        lhs = lhs + rhs
    }

    public static func -= (lhs: inout Self, rhs: Self) {
        lhs = lhs - rhs
    }
}
