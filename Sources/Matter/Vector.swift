import Foundation

#if canImport(CoreGraphics)
    import CoreGraphics
#endif

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

    #if canImport(CoreGraphics)
        /// Creates a finite physics vector from a native point.
        ///
        /// This checked bridge accepts P5 pointer-event locations without making
        /// either package depend on the other.
        public init(_ point: CGPoint) throws {
            let x = Float(point.x)
            let y = Float(point.y)
            guard x.isFinite, y.isFinite else { throw MatterError.invalidVector }
            self.init(x: x, y: y)
        }

        /// The native Core Graphics representation of this vector.
        public var cgPoint: CGPoint {
            CGPoint(x: CGFloat(x), y: CGFloat(y))
        }
    #endif

    /// The vector whose two components are zero.
    public static let zero = Self(x: 0, y: 0)

    /// Whether both components are finite.
    public var isFinite: Bool {
        x.isFinite && y.isFinite
    }

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

    /// Returns the two-dimensional scalar cross product with another vector.
    public func cross(_ other: Self) -> Float {
        (x * other.y) - (y * other.x)
    }

    /// Returns the Euclidean distance to another vector.
    public func distance(to other: Self) -> Float {
        (self - other).length
    }

    /// Returns this vector rotated clockwise by an angle in radians.
    public func rotated(by angle: Float) -> Self {
        let cosine = Foundation.cos(angle)
        let sine = Foundation.sin(angle)
        return Self(
            x: x * cosine - y * sine,
            y: x * sine + y * cosine
        )
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
