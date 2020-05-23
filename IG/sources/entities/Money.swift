import Foundation
#warning("Decimal64 change")

/// An amount of money in a given currency.
public struct Money<C:IG.CurrencyType>: RawRepresentable, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByStringLiteral, LosslessStringConvertible, SignedNumeric, Hashable, Comparable {
    public var rawValue: Decimal {
        willSet { precondition(newValue.isFinite) }
    }
    
    /// Designated initializer used for already-validated values.
    /// - parameter value: A "finite" value.
    @_transparent private init(trusted value: Decimal) {
        self.rawValue = value
    }
    
    public init?(rawValue: Decimal) {
        guard rawValue.isFinite else { return nil }
        self.init(trusted: rawValue)
    }
    
    public init?<T>(exactly source: T) where T: BinaryInteger {
        guard let rawValue = Decimal(exactly: source) else { return nil }
        self.init(rawValue: rawValue)
    }
    
    public init(integerLiteral value: Int) {
        self.init(trusted: Decimal(integerLiteral: value))
    }
    
    /// - important: Swift floating-point literals are currently initialized using binary floating-point number type, which cannot precisely express certain values. As a workaround, monetary amounts initialized from a floating-point literal are rounded to the number of places of the minor currency unit. To express a smaller fractional monetary amount, initialize from a string literal or decimal value instead.
    /// - bug: See Swift bug [SR-920](https://bugs.swift.org/browse/SR-920).
    public init(floatLiteral value: Double) {
        let result = Decimal(string: String(value)) ?! fatalError("The float literal '\(value)' couldn't be transformed into '\(Self.self)'")
        self.init(trusted: result)
    }
    
    public init(unicodeScalarLiteral value: Unicode.Scalar) {
        self.init(stringLiteral: String(value))
    }
    
    public init(extendedGraphemeClusterLiteral value: Character) {
        self.init(stringLiteral: String(value))
    }
    
    public init(stringLiteral value: String) {
        let result = Decimal(string: value) ?! fatalError("The string literal '\(value)' couldn't be transformed into '\(Self.self)")
        self.init(trusted: result)
    }
 
    public init?(_ description: String) {
        guard let amount = Decimal(string: description) else { return nil }
        self.init(rawValue: amount)
    }
    
    public var description: String {
        String(describing: self.rawValue)
    }
    
    public var magnitude: Self {
        Self.init(trusted: self.rawValue.magnitude)
    }
}

// MARK: - Functionality

extension IG.Money {
    /// The currency type.
    public var currency: C.Type {
        C.self
    }
    
    /// A monetary amount rounded to the number of places of the minor currency unit.
    public var rounded: Self {
        var source = self.rawValue
        var result = Decimal()
        
        #if canImport(Darwin)
        NSDecimalRound(&result, &source, C.minorUnit, .bankers)
        return Self.init(trusted: result)
        #else
        #error("Decimal rounding is not supported by non-Darwin platforms")
        #endif
    }
}

// MARK: - Operations

extension IG.Money {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    public static func + (lhs: Self, rhs: Self) -> Self {
        let result = lhs.rawValue + rhs.rawValue
        assert(result.isFinite, "The result of the '+' operation is infinite or NaN")
        return .init(trusted: result)
    }
    
    public static func += (lhs: inout Self, rhs: Self) {
        lhs.rawValue += rhs.rawValue
    }
    
    public static func - (lhs: Self, rhs: Self) -> Self {
        let result = lhs.rawValue - rhs.rawValue
        assert(result.isFinite, "The result of the '-' operation is infinite or NaN")
        return .init(trusted: result)
    }
    
    public static func -= (lhs: inout Self, rhs: Self) {
        lhs.rawValue -= rhs.rawValue
    }

    /// Subtracts one monetary amount from another.
    public static prefix func - (value: Self) -> Self {
        .init(trusted: -value.rawValue)
    }
    
    public static func * (lhs: Self, rhs: Self) -> Self {
        lhs * rhs.rawValue
    }
    
    public static func *= (lhs: inout Self, rhs: Self) {
        lhs *= rhs.rawValue
    }
}

extension IG.Money {
    /// The product of a monetary amount and a scalar value.
    public static func * (lhs: Self, rhs: Decimal) -> Self {
        let result = lhs.rawValue * rhs
        assert(result.isFinite, "The result of the '*' operation is infinite or NaN")
        return .init(trusted: result)
    }
    
    /// The product of a monetary amount and a scalar value.
    public static func *<I>(lhs: Self, rhs: I) -> Self where I:BinaryInteger {
        let value = Decimal(exactly: rhs) ?! fatalError("The binary integer '\(rhs)' couldn't be transformed into a Decimal number")
        return lhs * value
    }
    
    /// The product of a monetary amount and a scalar value.
    public static func * (lhs: Decimal, rhs: Self) -> Self {
        rhs * lhs
    }
    
    /// The product of a monetary amount and a scalar value.
    public static func *<I>(lhs: I, rhs: Self) -> Self where I:BinaryInteger {
        rhs * lhs
    }
    
    /// Multiplies a monetary amount by a scalar value.
    public static func *= (lhs: inout Self, rhs: Decimal) {
        lhs.rawValue *= rhs
    }
    
    /// Multiplies a monetary amount by a scalar value.
    public static func *=<I>(lhs: inout Self, rhs: I) where I:BinaryInteger {
        let value = Decimal(exactly: rhs) ?! fatalError("The binary integer '\(rhs)' couldn't be transformed into a Decimal number")
        lhs.rawValue *= value
    }
}

//extension IG.Money {
//    /// The product of a monetary amount and a scalar value.
//    /// - important: Multiplying a monetary amount by a floating-point number results in an amount rounded to the number of places of the minor currency unit. To produce a smaller fractional monetary amount, multiply by a `Decimal` value instead.
//    public static func * (lhs: Self, rhs: Double) -> Self {
//        return (lhs * Decimal(rhs)).rounded
//    }
//
//    /// The product of a monetary amount and a scalar value.
//    /// - important: Multiplying a monetary amount by a floating-point number results in an amount rounded to the number of places of the minor currency unit. To produce a smaller fractional monetary amount, multiply by a `Decimal` value instead.
//    public static func * (lhs: Double, rhs: Self) -> Self {
//        return rhs * lhs
//    }
//
//    /// Multiplies a monetary amount by a scalar value.
//    /// - important: Multiplying a monetary amount by a floating-point number results in an amount rounded to the number of places of the minor currency unit. To produce a smaller fractional monetary amount, multiply by a `Decimal` value instead.
//    public static func *= (lhs: inout Self, rhs: Double) {
//        lhs.amount = Self(lhs.amount * Decimal(rhs)).rounded.amount
//    }
//}
