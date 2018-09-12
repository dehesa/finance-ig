import Utils
import Foundation

extension DateFormatter {
    /// Debug error line to be used within the file's decoding functions.
    /// - parameter date: The date that couldn't be parsed from String to Date format.
    internal func parseErrorLine(date: String) -> String {
        return "Date \"\(date)\" couldn't be parsed with formatter \"\(self.dateFormat!)\""
    }
}

extension SingleValueDecodingContainer {
    /// Decodes a single value of the given type.
    ///
    /// - parameter type: The type to decode as.
    /// - parameter formatter: The date formatter to be used to parse the date.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   cannot be converted to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null.
    internal func decode(_ type: Date.Type, with formatter: Foundation.DateFormatter) throws -> Date {
        let dateString = try self.decode(String.self)
        return try formatter.date(from: dateString) ?! DecodingError.dataCorruptedError(in: self, debugDescription: formatter.parseErrorLine(date: dateString))
    }
}

extension UnkeyedDecodingContainer {
    /// Decodes a value of the given type.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter formatter: The date formatter to be used to parse the date.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.valueNotFound` if the encountered encoded value
    ///   is null, or of there are no more values to decode.
    internal mutating func decode(_ type: Date.Type, with formatter: Foundation.DateFormatter) throws -> Date {
        let dateString = try self.decode(String.self)
        return try formatter.date(from: dateString) ?! DecodingError.dataCorruptedError(in: self, debugDescription: formatter.parseErrorLine(date: dateString))
    }
    
    /// Decodes a value of the given type, if present.
    ///
    /// This method returns `nil` if the container has no elements left to
    /// decode, or if the value is null. The difference between these states can
    /// be distinguished by checking `isAtEnd`.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: A decoded value of the requested type, or `nil` if the value
    ///   is a null value, or if there are no more elements to decode.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    internal mutating func decodeIfPresent(_ type: Date.Type, with formatter: Foundation.DateFormatter) throws -> Date? {
        guard let dateString = try self.decodeIfPresent(String.self) else { return nil }
        return try formatter.date(from: dateString) ?! DecodingError.dataCorruptedError(in: self, debugDescription: formatter.parseErrorLine(date: dateString))
    }
}

extension KeyedDecodingContainer {
    /// Decodes a value of the given type for the given key.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - parameter formatter: The date formatter to be used to parse the date.
    /// - returns: A value of the requested type, if present for the given key
    ///   and convertible to the requested type.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    /// - throws: `DecodingError.keyNotFound` if `self` does not have an entry
    ///   for the given key.
    /// - throws: `DecodingError.valueNotFound` if `self` has a null entry for
    ///   the given key.
    internal func decode(_ type: Date.Type, forKey key: KeyedDecodingContainer<K>.Key, with formatter: Foundation.DateFormatter) throws -> Date {
        let dateString = try self.decode(String.self, forKey: key)
        return try formatter.date(from: dateString) ?! DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: formatter.parseErrorLine(date: dateString))
    }
    
    /// Decodes a value of the given type for the given key, if present.
    ///
    /// This method returns `nil` if the container does not have a value
    /// associated with `key`, or if the value is null. The difference between
    /// these states can be distinguished with a `contains(_:)` call.
    ///
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - parameter formatter: The date formatter to be used to parse the date.
    /// - returns: A decoded value of the requested type, or `nil` if the
    ///   `Decoder` does not have an entry associated with the given key, or if
    ///   the value is a null value.
    /// - throws: `DecodingError.typeMismatch` if the encountered encoded value
    ///   is not convertible to the requested type.
    internal func decodeIfPresent(_ type: Date.Type, forKey key: K, with formatter: Foundation.DateFormatter) throws -> Date? {
        guard let dateString = try self.decodeIfPresent(String.self, forKey: key) else { return nil }
        return try formatter.date(from: dateString) ?! DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: formatter.parseErrorLine(date: dateString))
    }
}
