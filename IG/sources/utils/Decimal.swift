import Foundation

extension Int {
    /// Convenience initializer to clamp a `Decimal` to an integer.
    /// - parameter source: The argument will lose all decimal places.
    internal init(clamping source: Decimal) {
        #if canImport(Darwin)
        self = (source as NSDecimalNumber).intValue
        #else
        #error("NSDecimalNumber is not supported on non Darwin platforms")
        #endif
    }
}

extension Int32 {
    /// Convenience initializer to clamp a `Decimal` to an integer.
    /// - parameter source: The argument will lose all decimal places.
    internal init(clamping source: Decimal) {
        #if canImport(Darwin)
        self = (source as NSDecimalNumber).int32Value
        #else
        #error("NSDecimalNumber is not supported on non Darwin platforms")
        #endif
    }
    /// Convenience initializer to multiply a `Decimal` by `10^power` and then clamp all decimal places.
    /// - parameter source: The decimal value from where the transformations will take place.
    /// - parameter power: The power to raise 10 to.
    init(clamping source: Decimal, multiplyingByPowerOf10 power: Int) {
        let rhs = pow(10 as Decimal, power)
        self = .init(clamping: source * rhs)
    }
}

extension Int64 {
    /// Convenience initializer to clamp a `Decimal` to an integer.
    /// - parameter source: The argument will lose all decimal places.
    internal init(clamping source: Decimal) {
        #if canImport(Darwin)
        self = (source as NSDecimalNumber).int64Value
        #else
        #error("NSDecimalNumber is not supported on non Darwin platforms")
        #endif
    }
    /// Convenience initializer to multiply a `Decimal` by `10^power` and then clamp all decimal places.
    /// - parameter source: The decimal value from where the transformations will take place.
    /// - parameter power: The power to raise 10 to.
    internal init(clamping source: Decimal, multiplyingByPowerOf10 power: Int) {
        let rhs = pow(10 as Decimal, power)
        self = .init(clamping: source * rhs)
    }
}

extension Double {
    /// Convenience initializer to transform a decimal into a double.
    /// - parameter source: The argument will lose all decimal places.
    internal init(_ source: Decimal) {
        #if canImport(Darwin)
        self = (source as NSDecimalNumber).doubleValue
        #else
        #error("NSDecimalNumber is not supported on non Darwin platforms")
        #endif
    }
}

extension Decimal {
    /// Convenience initializer to transformed the given value to a `Decimal` and then dividing it by the given power of 10.
    ///
    /// The operation is: `Decimal(value) / (10^power)`
    /// - precondition: `power` must be zero or a positive number.
    @inlinable internal init<I>(_ value: I, divingByPowerOf10 power: Int) where I:BinaryInteger {
        precondition(power > 0)
        let lhs: Decimal = Decimal(exactly: value)!
        let rhs: Decimal = pow(10 as Decimal, power)
        self = lhs / rhs
    }
    
    /// Convenience initializer to transformed the given value to a `Decimal` and then dividing it by the given power of 10.
    ///
    /// The operation is: `Decimal(value) / (10^power)`
    /// - precondition: `power` must be zero or a positive number.
    /// - parameter value: The integer value being transformed to a `Decimal`.
    /// - parameter power: The power which ten is being raised to (i.e. `10^power`).
    internal init(_ value: Int32, divingByPowerOf10 power: Int) {
        let lhs: Decimal = .init(value)
        let rhs: Decimal = pow(10 as Decimal, power)
        self = lhs / rhs
    }
    
    /// Convenience initializer to transformed the given value to a `Decimal` and then dividing it by the given power of 10.
    ///
    /// The operation is: `Decimal(value) / (10^power)`
    /// - precondition: `power` must be zero or a positive number.
    /// - parameter value: The integer value being transformed to a `Decimal`.
    /// - parameter power: The power which ten is being raised to (i.e. `10^power`).
    internal init(_ value: Int64, divingByPowerOf10 power: Int) {
        let lhs: Decimal = .init(value)
        let rhs: Decimal = pow(10 as Decimal, power)
        self = lhs / rhs
    }
    
    /// Boolean indicating whether the number has no decimals (is whole).
    internal var isWhole: Bool {
        var original = self.magnitude
        var rounded = Decimal()
        #if canImport(Darwin)
        NSDecimalRound(&rounded, &original, 0, .down)
        return original - rounded == 0
        #else
        #error("Decimal rounding is not supported by non-Darwin platforms")
        #endif
    }
}

// MARK: - Decoder

extension SingleValueDecodingContainer {
    /// Decodes a single value of the given type.
    /// - parameter type: The type to be decode as.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.dataCorruptedError` exclusively.
    internal func decode(_ type: Decimal.Type) throws -> Decimal {
        let double = try self.decode(Double.self)
        return try Decimal(double) { .dataCorruptedError(in: self, debugDescription: $0) }
    }
}

extension UnkeyedDecodingContainer {
    /// Decodes a value of the given type.
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.dataCorruptedError` exclusively.
    internal mutating func decode(_ type: Decimal.Type) throws -> Decimal {
        let double = try self.decode(Double.self)
        return try Decimal(double) { .dataCorruptedError(in: self, debugDescription: $0) }
    }
    
    /// Decodes a value of the given type, if present.
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.dataCorruptedError` exclusively.
    internal mutating func decodeIfPresent(_ type: Decimal.Type) throws -> Decimal? {
        guard let double = try self.decodeIfPresent(Double.self) else { return nil }
        return try Decimal(double) { .dataCorruptedError(in: self, debugDescription: $0) }
    }
}

extension KeyedDecodingContainer {
    /// Decodes a value of the given type for the given key.
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decode value is associated with.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    /// - throws: `DecodingError.dataCorruptedError` exclusively.
    internal func decode(_ type: Decimal.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> Decimal {
        let double = try self.decode(Double.self, forKey: key)
        return try Decimal(double) { .dataCorruptedError(forKey: key, in: self, debugDescription: $0) }
    }
    
    /// Decodes a value of the given type for the given key, if present.
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or  `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError.dataCorruptedError` exclusively.
    internal func decodeIfPresent(_ type: Decimal.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> Decimal? {
        guard let double = try self.decodeIfPresent(Double.self, forKey: key) else { return nil }
        return try Decimal(double) { .dataCorruptedError(forKey: key, in: self, debugDescription: $0) }
    }
}

// MARK: Supporting Functionality

extension Decimal {
    /// Creates a decimal value depending on the appropriate double value.
    ///
    /// This initializer is created to fight `JSONDecoder` mistake of transforming a number to double first and then to decimal.
    /// - parameter double: The number to transform to a `Decimal`.
    /// - parameter onError: The decoding error to generate in case the double was not able to be transformed.
    /// - throws: `DecodingError` exclusively. 
    fileprivate init(_ double: Double, onError: (_ message: String) -> DecodingError) throws {
        guard !double.isNaN && double.isFinite else {
            self.init(double); return
        }
        
        guard let result = Decimal(string: String(double)) else {
            throw onError("The double value '\(double)' couldn't be transformed into a Decimal")
        }
        
        self = result
    }
}
