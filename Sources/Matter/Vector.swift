/// A two-dimensional vector used by Matter's physics state.
@frozen
public struct Vector: Sendable, Hashable, Codable {
    /// The horizontal component.
    public var x: Float
    /// The vertical component.
    public var y: Float

    /// Creates a vector from horizontal and vertical components.
    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }

    /// The vector whose two components are zero.
    public static let zero = Self(x: 0, y: 0)

    /// The squared Euclidean length, avoiding a square root.
    public var lengthSquared: Float {
        (x * x) + (y * y)
    }

    /// The Euclidean length.
    public var length: Float {
        lengthSquared.squareRoot()
    }

    /// Returns the scalar dot product with another vector.
    public func dot(_ other: Self) -> Float {
        (x * other.x) + (y * other.y)
    }

    /// Returns a unit vector in the same direction, or ``zero`` for a zero vector.
    public func normalized() -> Self {
        let length = length
        guard length > 0 else { return .zero }
        return self / length
    }

    /// Returns the component-wise sum of two vectors.
    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    /// Returns the component-wise difference between two vectors.
    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    /// Returns a vector with both components negated.
    public static prefix func - (value: Self) -> Self {
        Self(x: -value.x, y: -value.y)
    }

    /// Returns the vector scaled by a scalar.
    public static func * (lhs: Self, rhs: Float) -> Self {
        Self(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    /// Returns the vector scaled by a scalar.
    public static func * (lhs: Float, rhs: Self) -> Self {
        rhs * lhs
    }

    /// Returns the vector divided by a scalar.
    ///
    /// Callers are responsible for supplying a nonzero finite divisor.
    public static func / (lhs: Self, rhs: Float) -> Self {
        Self(x: lhs.x / rhs, y: lhs.y / rhs)
    }

    /// Adds another vector component by component.
    public static func += (lhs: inout Self, rhs: Self) {
        lhs = lhs + rhs
    }

    /// Subtracts another vector component by component.
    public static func -= (lhs: inout Self, rhs: Self) {
        lhs = lhs - rhs
    }
}
