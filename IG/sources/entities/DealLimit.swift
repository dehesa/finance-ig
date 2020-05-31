import Decimals

extension Deal {
    /// The limit at which the user is taking profit.
    public enum Limit: Hashable, CustomDebugStringConvertible {
        /// Specifies the limit as a given absolute level.
        /// - parameter level: The absolute level where the limit will be set.
        case position(level: Decimal64)
        /// Relative limit over an undisclosed reference level.
        /// - parameter _: The relative value where the limit will be set.
        case distance(Decimal64)
        
        public var debugDescription: String {
            switch self {
            case .position(let level): return "Limit position at \(level)"
            case .distance(let dista): return "Limit distance of \(dista) pips"
            }
        }
    }
}

extension KeyedDecodingContainer {
    /// Decodes a limit level value for the given keys, if present.
    /// - parameter type: The type of value to decode.
    /// - parameter levelKey: The key that the limit level value is associated with.
    /// - parameter distanceKey: The key that the limit distance value is associated with.
    /// - returns: A decoded value of the deal limit type, or  `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError` exclusively.
    internal func decodeIfPresent(_ type: Deal.Limit.Type, forLevelKey levelKey: KeyedDecodingContainer<K>.Key?, distanceKey: KeyedDecodingContainer<K>.Key?) throws -> Deal.Limit? {
        let level = try levelKey.flatMap { try self.decodeIfPresent(Decimal64.self, forKey: $0) }
        let distance = try distanceKey.flatMap { try self.decodeIfPresent(Decimal64.self, forKey: $0) }
        
        switch (level, distance) {
        case (.none, .none):  return nil
        case (.none, let d?): return .distance(d)
        case (let l?, .none): return .position(level: l)
        case (let level?, let distance?): // If both the level and distance are provided, choose the distance if there are no fractional parts; Otherwise choose the level.
            switch distance.decomposed().fractional.isZero {
            case true: return .distance(distance)
            case false: return .position(level: level)
            }
        }
    }
}
