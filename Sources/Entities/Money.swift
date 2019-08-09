import Foundation

/// An amount of money in a given currency.
public struct Money<C:CurrencyType>: Equatable, Hashable {
    /// The amount of money.
    public var amount: Decimal
    
    /// Creates an amount of money with a given decimal number.
    public init(_ amount: Decimal) {
        self.amount = amount
    }
    
    /// The currency type.
    public var currency: C.Type {
        return C.self
    }
    
    /// A monetary amount rounded to the number of places of the minor currency unit.
//    public var rounded: Money<Currency> {
//        var approximate = self.amount
//        var rounded = Decimal()
//        NSDecimalRound(&rounded, &approximate, Currency.minorUnit, .bankers)
//
//        return Money<Currency>(rounded)
//    }
}

extension Money: CustomStringConvertible {
    public var description: String {
        return "\(self.amount)"
    }
}

// MARK: - Literal Initialization

extension Money: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(Decimal(integerLiteral: value))
    }
}

//extension Money: ExpressibleByFloatLiteral {
//    /// Creates a new value from the given floating-point literal.
//    /// - Important: Swift floating-point literals are currently initialized using binary floating-point number type, which cannot precisely express certain values. As a workaround, monetary amounts initialized from a floating-point literal are rounded to the number of places of the minor currency unit. To express a smaller fractional monetary amount, initialize from a string literal or decimal value instead.
//    /// - Bug: See https://bugs.swift.org/browse/SR-920
//    public init(floatLiteral value: Double) {
//        var approximate = Decimal(floatLiteral: value)
//        var rounded = Decimal()
//        NSDecimalRound(&rounded, &approximate, C.minorUnit, .bankers)
//        self.init(rounded)
//    }
//}

extension Money: ExpressibleByStringLiteral {
    public init(unicodeScalarLiteral value: Unicode.Scalar) {
        self.init(stringLiteral: String(value))
    }
    
    public init(extendedGraphemeClusterLiteral value: Character) {
        self.init(stringLiteral: String(value))
    }
    
    public init(stringLiteral value: String) {
        self.init(value)!
    }
}

extension Money: LosslessStringConvertible {
    public init?(_ description: String) {
        guard let amount = Decimal(string: description) else {
            return nil
        }
        
        self.init(amount)
    }
}

// MARK: - Operations

extension Money: Comparable {
    public static func < (lhs: Money<C>, rhs: Money<C>) -> Bool {
        return lhs.amount < rhs.amount
    }
}

extension Money: AdditiveArithmetic {
    /// The sum of two monetary amounts.
    public static func + (lhs: Money<C>, rhs: Money<C>) -> Money<C> {
        return Money<C>(lhs.amount + rhs.amount)
    }
    
    /// Adds one monetary amount to another.
    public static func += (lhs: inout Money<C>, rhs: Money<C>) {
        lhs.amount += rhs.amount
    }
    
    /// The difference between two monetary amounts.
    public static func - (lhs: Money<C>, rhs: Money<C>) -> Money<C> {
        return Money<C>(lhs.amount - rhs.amount)
    }
    
    /// Subtracts one monetary amount from another.
    public static func -= (lhs: inout Money<C>, rhs: Money<C>) {
        lhs.amount -= rhs.amount
    }
}

extension Money {
    /// Subtracts one monetary amount from another.
    public static prefix func - (value: Money<C>) -> Money<C> {
        return Money<C>(-value.amount)
    }
}

extension Money {
    /// The product of a monetary amount and a scalar value.
    public static func * (lhs: Money<C>, rhs: Decimal) -> Money<C> {
        return Money<C>(lhs.amount * rhs)
    }
    
    /// The product of a monetary amount and a scalar value.
    /// - Important: Multiplying a monetary amount by a floating-point number results in an amount rounded to the number of places of the minor currency unit. To produce a smaller fractional monetary amount, multiply by a `Decimal` value instead.
//    public static func * (lhs: Money<C>, rhs: Double) -> Money<C> {
//        return (lhs * Decimal(rhs)).rounded
//    }
    
    /// The product of a monetary amount and a scalar value.
    public static func * (lhs: Money<C>, rhs: Int) -> Money<C> {
        return lhs * Decimal(rhs)
    }
    
    /// The product of a monetary amount and a scalar value.
    public static func * (lhs: Decimal, rhs: Money<C>) -> Money<C> {
        return rhs * lhs
    }
    
    /// The product of a monetary amount and a scalar value.
    /// - Important: Multiplying a monetary amount by a floating-point number results in an amount rounded to the number of places of the minor currency unit. To produce a smaller fractional monetary amount, multiply by a `Decimal` value instead.
//    public static func * (lhs: Double, rhs: Money<C>) -> Money<C> {
//        return rhs * lhs
//    }
    
    /// The product of a monetary amount and a scalar value.
    public static func * (lhs: Int, rhs: Money<C>) -> Money<C> {
        return rhs * lhs
    }
    
    /// Multiplies a monetary amount by a scalar value.
    public static func *= (lhs: inout Money<C>, rhs: Decimal) {
        lhs.amount *= rhs
    }
    
    /// Multiplies a monetary amount by a scalar value.
    /// - Important: Multiplying a monetary amount by a floating-point number results in an amount rounded to the number of places of the minor currency unit. To produce a smaller fractional monetary amount, multiply by a `Decimal` value instead.
//    public static func *= (lhs: inout Money<C>, rhs: Double) {
//        lhs.amount = Money<C>(lhs.amount * Decimal(rhs)).rounded.amount
//    }
    
    /// Multiplies a monetary amount by a scalar value.
    public static func *= (lhs: inout Money<C>, rhs: Int) {
        lhs.amount *= Decimal(rhs)
    }
}
