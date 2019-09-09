import Foundation

/// An amount of money in a given currency.
public struct Money<C:IG.CurrencyType>: Equatable, Hashable {
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
    public var rounded: Self {
        var approximate = self.amount
        var rounded = Decimal()
        
        #if canImport(Darwin)
        NSDecimalRound(&rounded, &approximate, C.minorUnit, .bankers)
        return Self.init(rounded)
        #else
        #error("Decimal rounding is not supported by non-Darwin platforms")
        #endif
    }
}

extension IG.Money: CustomStringConvertible {
    public var description: String {
        return "\(self.amount)"
    }
}

// MARK: - Literal Initialization

extension IG.Money: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(Decimal(integerLiteral: value))
    }
}

extension IG.Money: ExpressibleByFloatLiteral {
    /// Creates a new value from the given floating-point literal.
    /// - important: Swift floating-point literals are currently initialized using binary floating-point number type, which cannot precisely express certain values. As a workaround, monetary amounts initialized from a floating-point literal are rounded to the number of places of the minor currency unit. To express a smaller fractional monetary amount, initialize from a string literal or decimal value instead.
    /// - bug: See Swift bug [SR-920](https://bugs.swift.org/browse/SR-920).
    public init(floatLiteral value: Double) {
        guard let result = Decimal(string: String(value)) else {
            fatalError(#"The float literal "\#(value)" couldn't be transformed into "\#(Self.self)""#)
        }
        self.init(result)
    }
}

extension IG.Money: ExpressibleByStringLiteral {
    public init(unicodeScalarLiteral value: Unicode.Scalar) {
        self.init(stringLiteral: String(value))
    }
    
    public init(extendedGraphemeClusterLiteral value: Character) {
        self.init(stringLiteral: String(value))
    }
    
    public init(stringLiteral value: String) {
        guard let result = Decimal(string: value) else {
            fatalError(#"The string literal "\#(value)" couldn't be transformed into "\#(Self.self)""#)
        }
        self.init(result)
    }
}

extension IG.Money: LosslessStringConvertible {
    public init?(_ description: String) {
        guard let amount = Decimal(string: description) else {
            return nil
        }
        
        self.init(amount)
    }
}

// MARK: - Operations

extension IG.Money: Comparable {
    public static func < (lhs: IG.Money<C>, rhs: IG.Money<C>) -> Bool {
        return lhs.amount < rhs.amount
    }
}

extension IG.Money: AdditiveArithmetic {
    /// The sum of two monetary amounts.
    public static func + (lhs: IG.Money<C>, rhs: IG.Money<C>) -> IG.Money<C> {
        return .init(lhs.amount + rhs.amount)
    }
    
    /// Adds one monetary amount to another.
    public static func += (lhs: inout IG.Money<C>, rhs: IG.Money<C>) {
        lhs.amount += rhs.amount
    }
    
    /// The difference between two monetary amounts.
    public static func - (lhs: IG.Money<C>, rhs: IG.Money<C>) -> IG.Money<C> {
        return .init(lhs.amount - rhs.amount)
    }
    
    /// Subtracts one monetary amount from another.
    public static func -= (lhs: inout IG.Money<C>, rhs: IG.Money<C>) {
        lhs.amount -= rhs.amount
    }
}

extension IG.Money {
    /// Subtracts one monetary amount from another.
    public static prefix func - (value: IG.Money<C>) -> IG.Money<C> {
        return .init(-value.amount)
    }
}

extension IG.Money {
    /// The product of a monetary amount and a scalar value.
    public static func * (lhs: IG.Money<C>, rhs: Decimal) -> IG.Money<C> {
        return .init(lhs.amount * rhs)
    }
    
//    /// The product of a monetary amount and a scalar value.
//    /// - important: Multiplying a monetary amount by a floating-point number results in an amount rounded to the number of places of the minor currency unit. To produce a smaller fractional monetary amount, multiply by a `Decimal` value instead.
//    public static func * (lhs: IG.Money<C>, rhs: Double) -> IG.Money<C> {
//        return (lhs * Decimal(rhs)).rounded
//    }
    
    /// The product of a monetary amount and a scalar value.
    public static func * (lhs: IG.Money<C>, rhs: Int) -> IG.Money<C> {
        return lhs * Decimal(rhs)
    }
    
    /// The product of a monetary amount and a scalar value.
    public static func * (lhs: Decimal, rhs: IG.Money<C>) -> IG.Money<C> {
        return rhs * lhs
    }
    
//    /// The product of a monetary amount and a scalar value.
//    /// - important: Multiplying a monetary amount by a floating-point number results in an amount rounded to the number of places of the minor currency unit. To produce a smaller fractional monetary amount, multiply by a `Decimal` value instead.
//    public static func * (lhs: Double, rhs: IG.Money<C>) -> IG.Money<C> {
//        return rhs * lhs
//    }
    
    /// The product of a monetary amount and a scalar value.
    public static func * (lhs: Int, rhs: IG.Money<C>) -> IG.Money<C> {
        return rhs * lhs
    }
    
    /// Multiplies a monetary amount by a scalar value.
    public static func *= (lhs: inout IG.Money<C>, rhs: Decimal) {
        lhs.amount *= rhs
    }
    
//    /// Multiplies a monetary amount by a scalar value.
//    /// - important: Multiplying a monetary amount by a floating-point number results in an amount rounded to the number of places of the minor currency unit. To produce a smaller fractional monetary amount, multiply by a `Decimal` value instead.
//    public static func *= (lhs: inout IG.Money<C>, rhs: Double) {
//        lhs.amount = IG.Money<C>(lhs.amount * Decimal(rhs)).rounded.amount
//    }
    
    /// Multiplies a monetary amount by a scalar value.
    public static func *= (lhs: inout IG.Money<C>, rhs: Int) {
        lhs.amount *= Decimal(rhs)
    }
}
