import Decimals

/// An amount of money in a given currency.
public struct Money<C:CurrencyType>: RawRepresentable, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByStringLiteral, LosslessStringConvertible, AdditiveArithmetic, Hashable, Comparable {
    public var rawValue: Decimal64
    
    /// Designated initializer used for already-validated values.
    /// - parameter value: A "finite" value.
    @_transparent private init(trusted value: Decimal64) {
        self.rawValue = value
    }
    
    public init?(rawValue: Decimal64) {
        self.init(trusted: rawValue)
    }
    
    public init?<T>(exactly source: T) where T: BinaryInteger {
        guard let rawValue = Decimal64(exactly: source) else { return nil }
        self.init(rawValue: rawValue)
    }
    
    public init(integerLiteral value: Int) {
        self.init(trusted: Decimal64(integerLiteral: Int64(value)))
    }
    
    /// - important: Swift floating-point literals are currently initialized using binary floating-point number type, which cannot precisely express certain values. As a workaround, monetary amounts initialized from a floating-point literal are rounded to the number of places of the minor currency unit. To express a smaller fractional monetary amount, initialize from a string literal or decimal value instead.
    /// - bug: See Swift bug [SR-920](https://bugs.swift.org/browse/SR-920).
    public init(floatLiteral value: Double) {
        let result = Decimal64(floatLiteral: value) ?! fatalError("The float literal '\(value)' couldn't be transformed into '\(Self.self)'")
        self.init(trusted: result)
    }
    
    public init(unicodeScalarLiteral value: Unicode.Scalar) {
        self.init(stringLiteral: String(value))
    }
    
    public init(extendedGraphemeClusterLiteral value: Character) {
        self.init(stringLiteral: String(value))
    }
    
    public init(stringLiteral value: String) {
        let result = Decimal64(stringLiteral: value) ?! fatalError("The string literal '\(value)' couldn't be transformed into '\(Self.self)")
        self.init(trusted: result)
    }
 
    public init?(_ description: String) {
        guard let amount = Decimal64(description) else { return nil }
        self.init(rawValue: amount)
    }
    
    public var description: String {
        self.rawValue.description
    }
    
    public var magnitude: Self {
        .init(trusted: self.rawValue.magnitude)
    }
}

// MARK: - Functionality

extension Money {
    /// The currency type.
    @_transparent public var currency: C.Type {
        C.self
    }
    
    /// A monetary amount rounded to the number of places of the minor currency unit.
    public var rounded: Self {
        .init(trusted: self.rawValue.rounded(.toNearestOrEven, scale: C.minorUnit))
    }
}

// MARK: - Operations

extension Money {
    @_transparent public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    public static func + (lhs: Self, rhs: Self) -> Self {
        .init(trusted: lhs.rawValue + rhs.rawValue)
    }
    
    @_transparent public static func += (lhs: inout Self, rhs: Self) {
        lhs.rawValue += rhs.rawValue
    }
    
    public static func - (lhs: Self, rhs: Self) -> Self {
        .init(trusted: lhs.rawValue - rhs.rawValue)
    }
    
    @_transparent public static func -= (lhs: inout Self, rhs: Self) {
        lhs.rawValue -= rhs.rawValue
    }

    /// Subtracts one monetary amount from another.
    public static prefix func - (value: Self) -> Self {
        .init(trusted: -value.rawValue)
    }
}

extension Money {
    /// The product of a monetary amount and a scalar value.
    public static func * (lhs: Self, rhs: Decimal64) -> Self {
        .init(trusted: lhs.rawValue * rhs)
    }
    
    /// The product of a monetary amount and a scalar value.
    @inlinable public static func *<I>(lhs: Self, rhs: I) -> Self where I:BinaryInteger {
        let value = Decimal64(exactly: rhs) ?! fatalError("The binary integer '\(rhs)' couldn't be transformed into a Decimal64 number")
        return lhs * value
    }
    
    /// The product of a monetary amount and a scalar value.
    @_transparent public static func * (lhs: Decimal64, rhs: Self) -> Self {
        rhs * lhs
    }
    
    /// The product of a monetary amount and a scalar value.
    @_transparent public static func *<I>(lhs: I, rhs: Self) -> Self where I:BinaryInteger {
        rhs * lhs
    }
    
    /// Multiplies a monetary amount by a scalar value.
    @_transparent public static func *= (lhs: inout Self, rhs: Decimal64) {
        lhs.rawValue *= rhs
    }
    
    /// Multiplies a monetary amount by a scalar value.
    @inlinable public static func *=<I>(lhs: inout Self, rhs: I) where I:BinaryInteger {
        let value = Decimal64(exactly: rhs) ?! fatalError("The binary integer '\(rhs)' couldn't be transformed into a Decimal64 number")
        lhs.rawValue *= value
    }
}
