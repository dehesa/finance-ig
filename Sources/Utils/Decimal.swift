import Foundation

// MARK: - Decoder

extension SingleValueDecodingContainer {
    /// Decodes a single value of the given type.
    /// - parameter type: The type to be decode as.
    /// - returns: A value of the requested type.
    internal func decode(_ type: Decimal.Type) throws -> Decimal {
        let double = try self.decode(Double.self)
        return try Decimal(double) { .dataCorruptedError(in: self, debugDescription: $0) }
    }
}

extension UnkeyedDecodingContainer {
    /// Decodes a value of the given type.
    /// - parameter type: The type of value to decode.
    /// - returns: A value of the requested type, if present for the given key and convertible to the requested type.
    internal mutating func decode(_ type: Decimal.Type) throws -> Decimal {
        let double = try self.decode(Double.self)
        return try Decimal(double) { .dataCorruptedError(in: self, debugDescription: $0) }
    }
    
    /// Decodes a value of the given type, if present.
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value is a null value, or if there are no more elements to decode.
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
    internal func decode(_ type: Decimal.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> Decimal {
        let double = try self.decode(Double.self, forKey: key)
        return try Decimal(double) { .dataCorruptedError(forKey: key, in: self, debugDescription: $0) }
    }
    
    /// Decodes a value of the given type for the given key, if present.
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - returns: A decoded value of the requested type, or  `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
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
    fileprivate init(_ double: Double, onError: (_ message: String) -> DecodingError) throws {
        guard !double.isNaN && double.isFinite else {
            self.init(double); return
        }
        
        guard let result = Decimal(string: String(double)) else {
            throw onError("The double value \"\(double)\" couldn't be transformed into a Decimal.")
        }
        
        self = result
    }
}
