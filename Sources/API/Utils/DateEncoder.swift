import Utils
import Foundation

extension SingleValueEncodingContainer {
    /// Encodes a single value of the given type.
    ///
    /// - parameter value: The value to encode.
    /// - parameter formatter: The date formatter to be used to transform the date into a string.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    /// - precondition: May not be called after a previous `self.encode(_:)`
    ///   call.
    public mutating func encode(_ value: Date, with formatter: Foundation.DateFormatter) throws {
        let dateString = formatter.string(from: value)
        try self.encode(dateString)
    }
}

extension UnkeyedEncodingContainer {
    /// Encodes the given value.
    ///
    /// - parameter value: The value to encode.
    /// - parameter formatter: The date formatter to be used to transform the date into a string.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    public mutating func encode(_ value: Date, with formatter: Foundation.DateFormatter) throws {
        let dateString = formatter.string(from: value)
        try self.encode(dateString)
    }
}

extension KeyedEncodingContainer {
    /// Encodes the given value for the given key.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - parameter formatter: The date formatter to be used to transform the date into a string.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    public mutating func encode(_ value: Date, forKey key: KeyedEncodingContainer<K>.Key, with formatter: Foundation.DateFormatter) throws {
        let dateString = formatter.string(from: value)
        try self.encode(dateString, forKey: key)
    }

    /// Encodes the given value for the given key if it is not `nil`.
    ///
    /// - parameter value: The value to encode.
    /// - parameter key: The key to associate the value with.
    /// - parameter formatter: The date formatter to be used to transform the date into a string.
    /// - throws: `EncodingError.invalidValue` if the given value is invalid in
    ///   the current context for this format.
    public mutating func encodeIfPresent(_ value: Date?, forKey key: KeyedEncodingContainer<K>.Key, with formatter: Foundation.DateFormatter) throws {
        let dateString = value.map { formatter.string(from: $0) }
        try self.encodeIfPresent(dateString, forKey: key)
    }
}
