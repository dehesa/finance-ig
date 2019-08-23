import Foundation

extension Deal {
    /// The limit at which the user is taking profit.
    public struct Limit {
        /// The type of limit being defined.
        public let type: Self.Kind
        
        /// Designated initializer.
        /// - parameter type: The type of limit being set.
        /// - attention: No check are performed on this initializer.
        private init(_ type: Self.Kind) {
            self.type = type
        }
    }
}

extension Deal.Limit {
    /// Check whether the receiving limit is valid in reference to the given base level and direction.
    /// - parameter direction: The deal direction.
    /// - parameter base: The deal/base level.
    public func isValid(on direction: IG.Deal.Direction, from base: Decimal) -> Bool {
        switch self.type {
        case .position(let level):
            return Self.isValid(level: level, direction, from: base)
        case .distance:
            return true
        }
    }
    
    /// The `Decimal` value stored with the limit type (whether a relative distance or a level.
    internal var value: Decimal {
        switch self.type {
        case .position(let level): return level
        case .distance(let distance): return distance
        }
    }
    
    /// Returns the absolute limit level.
    /// - parameter direction: The deal direction.
    /// - parameter base: The deal/base level.
    public func level(_ direction: IG.Deal.Direction, from base: Decimal) -> Decimal? {
        switch self.type {
        case .position(let level):
            guard Self.isValid(level: level, direction, from: base) else { return nil }
            return level
        case .distance(let distance):
            switch direction {
            case .buy:  return base + distance
            case .sell: return base - distance
            }
        }
    }
    
    /// Returns the distance from the base to the limit level.
    /// - parameter direction: The deal direction.
    /// - parameter base: The deal/base level.
    public func distance(_ direction: IG.Deal.Direction, from base: Decimal) -> Decimal? {
        switch self.type {
        case .position(let level):
            guard Self.isValid(level: base) else { return nil }
            switch direction {
            case .buy:  return level - base
            case .sell: return base - level
            }
        case .distance(let distance):
            return distance
        }
    }
}

// MARK: - Factories

extension Deal.Limit {
    /// Factory function creating a limit of *position* type.
    /// - parameter level: A finite number reflecting an absolute level.
    public static func position(level: Decimal) -> Self? {
        guard Self.isValid(level: level) else { return nil }
        return .init(.position(level: level))
    }
    
    /// Factory function creating a limit of *position* type.
    /// - parameter level: A finite number reflecting an absolute level.
    /// - parameter direction: The deal direction.
    /// - parameter base: The deal/base level.
    public static func position(level: Decimal, _ direction: IG.Deal.Direction, from base: Decimal) -> Self? {
        guard Self.isValid(level: level, direction, from: base) else { return nil }
        return .init(.position(level: level))
    }
    
    /// Factory function creating a limit of *distance* type.
    /// - parameter distance: A positive (non-zero) number reflecting a relative distance.
    public static func distance(_ distance: Decimal) -> Self? {
        guard Self.isValid(distance: distance) else { return nil }
        return .init(.distance(distance))
    }
}

// MARK: - Validation

extension Deal.Limit {
    /// Checks that the absolute level is finite.
    /// - parameter level: A number reflecting an absolute level.
    /// - Boolean indicating whether the argument will work as a *position* level.
    public static func isValid(level: Decimal) -> Bool {
        return level.isFinite
    }
    
    /// Checks that the given level is finite and greater than the base level on a `.buy` direction and less than the base level on a `.sell` direction.
    /// - parameter level: The limit level.
    /// - parameter direction: The deal direction.
    /// - parameter base: The deal/base level.
    public static func isValid(level: Decimal, _ direction: IG.Deal.Direction, from base: Decimal) -> Bool {
        guard Self.isValid(level: level) && Self.isValid(level: base) else { return false }
        switch direction {
        case .buy:  return level > base
        case .sell: return level < base
        }
    }
    
    /// Checks that the distance is a valid number.
    /// - parameter distance: A number reflecting a relative distance.
    /// - Boolean indicating whether the argument will work as a *distance* level.
    public static func isValid(distance: Decimal) -> Bool {
        return distance.isFinite
    }
}

// MARK: - Supporting Entities

extension Deal.Limit {
    /// The type of limit level.
    public enum Kind {
        /// Specifies the limit as a given absolute level.
        /// - parameter level: The absolute level where the limit will be set.
        case position(level: Decimal)
        /// Relative limit over an undisclosed reference level.
        /// - parameter _: The relative value where the limit will be set.
        case distance(Decimal)
    }
}

// MARK: Keyed Decoder

extension KeyedDecodingContainer {
    /// Decodes a limit level value for the given keys, if present.
    /// - parameter type: The type of value to decode.
    /// - parameter levelKey: The key that the limit level value is associated with.
    /// - parameter distanceKey: The key that the limit distance value is associated with.
    /// - returns: A decoded value of the deal limit type, or  `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    internal func decodeIfPresent(_ type: IG.Deal.Limit.Type, forLevelKey levelKey: KeyedDecodingContainer<K>.Key?, distanceKey: KeyedDecodingContainer<K>.Key?) throws -> IG.Deal.Limit? {
        
        typealias L = IG.Deal.Limit
        
        let level = try levelKey.flatMap { try self.decodeIfPresent(Decimal.self, forKey: $0) }
        let distance = try distanceKey.flatMap { try self.decodeIfPresent(Decimal.self, forKey: $0) }
        switch (level, distance) {
        case (.none, .none):
            return nil
        case (.none, let distance?):
            return .distance(distance)
        case (let level?, .none):
            return .position(level: level)
        case (let level?, let distance?):
            var possibleLimit: L? = nil
            // Whole numbers are prefered as distances.
            if let limit = L.distance(distance) {
                if distance.isWhole {
                    return limit
                }
                possibleLimit = limit
            }

            if let limit = L.position(level: level) {
                return limit
            }
            
            guard let limit = possibleLimit else {
                let msg = #"The limit level "\#(level)" and/or the limit distance "\#(distance)" decoded were invalid."#
                throw DecodingError.dataCorruptedError(forKey: levelKey!, in: self, debugDescription: msg)
            }
            return limit
        }
    }
}

extension Deal.Limit: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = "Limit "
        
        switch self.type {
        case .position(let level): result.append("position at \(level)")
        case .distance(let dista): result.append("distance of \(dista) pips")
        }
        
        result.append(".")
        return result
    }
}
