import Foundation

extension IG.Deal {
    /// The level/price at which the user doesn't want to incur more lose.
    public struct Stop {
        /// The type of stop (whether absolute level or relative distance).
        public let type: Self.Kind
        /// The type of risk the user is assuming when the stop is hit.
        public let risk: Self.Risk
        ///  Whether the stop is a "trailing stop" or a "static stop".
        public let trailing: Self.Trailing
        
        /// Designated initializer.
        /// - parameter type: The type of stop (whether an absolute stop level or relative stop distance).
        /// - parameter risk: The risk exposed when exercising the stop loss.
        /// - parameter trailing: Indicates whether the stop should be dynamic (i.e. trailing) or static (i.e. not trailing).
        /// - attention: No checks are performed on this initializer.
        private init(_ type: Self.Kind, risk: Self.Risk, trailing: Self.Trailing) {
            self.type = type
            self.risk = risk
            self.trailing = trailing
        }
    }
}

extension IG.Deal.Stop {
    /// Check whether the receiving stop is valid in reference to the given base level and direction.
    /// - parameter reference. The reference level and deal direction.
    /// - returns: Boolean indicating whether the stop is in the right side of the deal and the number is valid.
    public func isValid(on direction: IG.Deal.Direction, from base: Decimal) -> Bool {
        switch self.type {
        case .position(let l): return Self.isValid(level: l, direction, from: base)
        case .distance: return true
        }
    }
    
    /// Boolean indicating whether the stop will trail (be dynamic) or not (be static).
    public var isTrailing: Bool {
        switch self.trailing {
        case .static:  return false
        case .dynamic: return true
        }
    }
    
    /// The `Decimal` value stored with the stop type (whether a relative distance or a level.
    internal var value: Decimal {
        switch self.type {
        case .position(let l): return l
        case .distance(let d): return d
        }
    }
    
    /// Returns the absolute stop level.
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
    
    /// Returns the distance from the base to the stop level.
    /// - parameter direction: The deal direction.
    /// - parameter base: The deal/base level.
    public func distance(_ direction: IG.Deal.Direction, from base: Decimal) -> Decimal? {
        switch self.type {
        case .position(let level):
            guard Self.isValid(level: level, direction, from: base) else { return nil }
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

extension IG.Deal.Stop {
    /// Creates a stop level based on an absolute level value.
    ///
    /// A guaranteed stop pays an extra premium (indicated by the server).
    /// - parameter level: The absolute level value at which the stop will be.
    /// - parameter isStopGuaranteed: Indicates when at the stop activation time, the filling risk is limited or exposed.
    public static func position(level: Decimal, isStopGuaranteed: Bool = false) -> Self? {
        guard Self.isValid(level: level) else { return nil }
        return self.init(.position(level: level), risk: (isStopGuaranteed) ? .limited(premium: nil) : .exposed, trailing: .static)
    }
    
    /// Creates a stop level based on an absolute level value.
    ///
    /// A guaranteed stop pays an extra premium (indicated by the server).
    /// - parameter level: The absolute level value at which the stop will be.
    /// - parameter risk: Indicates, when the stop is activitated, whether the filling risk is exposed or limited (with the exact risk premium).
    /// - parameter trailing: Indicates whether the stop should be dynamic (i.e. trailing) or static (i.e. not trailing).
    internal static func position(level: Decimal, risk: Self.Risk, trailing: Self.Trailing) -> Self? {
        guard Self.isValid(level: level) else { return nil }
        if case .limited(let premium?) = risk,
           !Self.Risk.isValid(premium: premium) { return nil }
        if case .dynamic(let settings?) = trailing,
           !Self.Trailing.Settings.isValid(settings.distance) || !Self.Trailing.Settings.isValid(settings.increment) { return nil }
        return self.init(.position(level: level), risk: risk, trailing: .static)
    }
    
    /// Creates a stop level based on an absolute level value.
    ///
    /// A guaranteed stop pays an extra premium (indicated by the server).
    /// - parameter level: The absolute level value at which the stop will be.
    /// - parameter risk: Indicates, when the stop is activitated, whether the filling risk is exposed or limited (with the exact risk premium).
    /// - parameter trailing: Indicates whether the stop should be dynamic (i.e. trailing) or static (i.e. not trailing).
    /// - parameter direction: The deal direction.
    /// - parameter base: The deal/base level.
    internal static func position(level: Decimal, risk: Self.Risk, trailing: Self.Trailing, _ direction: IG.Deal.Direction, from base: Decimal) -> Self? {
        guard Self.isValid(level: level, direction, from: base) else { return nil }
        if case .limited(let premium?) = risk,
           !Self.Risk.isValid(premium: premium) { return nil }
        if case .dynamic(let settings?) = trailing,
           !Self.Trailing.Settings.isValid(settings.distance) || !Self.Trailing.Settings.isValid(settings.increment) { return nil }
        return self.init(.position(level: level), risk: risk, trailing: .static)
    }
    
    /// Creates a stop level based on a relative distince from the base level (not specified here).
    ///
    /// A guaranteed stop pays an extra premium (indicated by the server).
    /// - parameter distance: A positive number which will get added or substracted from the base level depending on the direction of the deal.
    /// - parameter isStopGuaranteed: Indicates, when the stop is activited, whether the filling risk is limited or exposed.
    public static func distance(_ distance: Decimal, isStopGuaranteed: Bool = false) -> Self? {
        guard Self.isValid(distance: distance) else { return nil }
        return self.init(.distance(distance), risk: (isStopGuaranteed) ? .limited(premium: nil) : .exposed, trailing: .static)
    }
    
    /// Creates a stop level based on a relative distince from the base level (not specified here).
    ///
    /// A guaranteed stop pays an extra premium (indicated by the server).
    /// - parameter distance: A positive number which will get added or substracted from the base level depending on the direction of the deal.
    /// - parameter risk: Indicates, when the stop is activitated, whether the filling risk is exposed or limited (with the exact risk premium).
    /// - parameter trailing: Indicates whether the stop should be dynamic (i.e. trailing) or static (i.e. not trailing).
    internal static func distance(_ distance: Decimal, risk: Self.Risk, trailing: Self.Trailing) -> Self? {
        guard Self.isValid(distance: distance) else { return nil }
        if case .limited(let premium?) = risk,
           !Self.Risk.isValid(premium: premium) { return nil }
        if case .dynamic(let settings?) = trailing,
           !Self.Trailing.Settings.isValid(settings.distance) || !Self.Trailing.Settings.isValid(settings.increment) { return nil }
        return self.init(.distance(distance), risk: risk, trailing: .static)
    }
    
    /// Creates a stop level based on a relative distince from the base level (not specified here).
    ///
    /// A guaranteed stop pays an extra premium (indicated by the server).
    /// - parameter distance: A positive number which will get added or substracted from the base level depending on the direction of the deal.
    /// - parameter increment: The increment/steps taken everytime the deals go in your favor and the distance from the base level is smaller than `distance`.
    /// - parameter isStopGuaranteed: Indicates when at the stop activation time, the filling risk is limited or exposed.
    public static func trailing(_ distance: Decimal, increment: Decimal) -> Self? {
        typealias S = Self.Trailing.Settings
        guard S.isValid(distance) && S.isValid(increment) else { return nil }
        return self.init(.distance(distance), risk: .exposed, trailing: .dynamic(.init(distance: distance, increment: increment)))
    }
}

// MARK: - Validation

extension IG.Deal.Stop {
    /// Checks that the absolute level is finite.
    /// - parameter level: A number reflecting an absolute level.
    /// - Boolean indicating whether the argument will work as a *position* level.
    public static func isValid(level: Decimal) -> Bool {
        return level.isFinite
    }
    
    /// Checks that the given level is finite and lower than the base level on a `.buy` direction and greater than the base level on a `.sell` direction.
    /// - parameter level: The stop level.
    /// - parameter direction: The deal direction.
    /// - parameter base: The deal/base level.
    public static func isValid(level: Decimal, _ direction: IG.Deal.Direction, from base: Decimal) -> Bool {
        guard Self.isValid(level: level) && Self.isValid(level: base) else { return false }
        switch direction {
        case .buy:  return level < base
        case .sell: return level > base
        }
    }
    
    /// Checks that the distance is not zero and it is a positive number.
    /// - parameter distance: A number reflecting a relative distance.
    /// - Boolean indicating whether the argument will work as a *distance* level.
    public static func isValid(distance: Decimal) -> Bool {
        return distance.isFinite
    }
}

// MARK: - Supporting Entities

extension IG.Deal.Stop {
    /// Available types of stops.
    public enum Kind {
        /// Absolute value of the stop (e.g. 1.653 USD/EUR).
        /// - parameter level: The stop absolute level.
        case position(level: Decimal)
        /// Relative stop over an undisclosed reference level.
        case distance(Decimal)
    }
}

extension IG.Deal.Stop {
    /// Defines the amount of risk being exposed while closing the stop loss.
    public enum Risk: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral {
        /// A guaranteed stop is a stop-loss order that puts an absolute limit on your liability, eliminating the chance of slippage and guaranteeing an exit price for your trade.
        /// - parameter premium: The number of pips that are being charged for your limited risk (i.e. guaranteed stop).
        case limited(premium: Decimal? = nil)
        /// An exposed (or non-guaranteed) stop may expose the trade to slippage when exiting it.
        case exposed
        
        public init(nilLiteral: ()) {
            self = .exposed
        }
        
        public init(booleanLiteral value: Bool) {
            self = (value) ? .exposed : .limited(premium: nil)
        }
        
        /// Check whether the given premium is valid.
        internal static func isValid(premium: Decimal) -> Bool {
            return premium.isNormal && !premium.isSignMinus
        }
    }
}

extension IG.Deal.Stop {
    /// A distance from the buy/sell level which will be moved towards the current level in case of a favourable trade.
    public enum Trailing: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral {
        /// A static (non-movable) stop.
        case `static`
        /// A dynamic (trailing) stop.
        case `dynamic`(Self.Settings? = nil)
        
        public init(nilLiteral: ()) {
            self = .static
        }
        
        public init(booleanLiteral value: Bool) {
            self = (value) ? .dynamic(nil) : .static
        }
        
        /// The trailing settings (i.e. trailing distance and trailing increment/step).
        public struct Settings: Equatable, ExpressibleByArrayLiteral {
            /// The distance from the  market price.
            public let distance: Decimal
            /// The stop level increment step in pips.
            public let increment: Decimal
            /// Designated initializer.
            fileprivate init(distance: Decimal, increment: Decimal) {
                self.distance = distance
                self.increment = increment
            }
            
            public init(arrayLiteral elements: Decimal...) {
                guard elements.count == 2 else {
                    fatalError("Only 2 elements are allowed for trailing stop settings (i.e. trailing stop distances and trailing stop increment). You have set \(elements.count) elements.")
                }
                
                let distance = elements[0]
                let increment = elements[1]
                guard Self.isValid(distance) && Self.isValid(increment) else {
                    fatalError(#"The stop trailing distance "\#(distance)" or increment "\#(increment)" are invalid."#)
                }
                self.init(distance: elements[0], increment: elements[1])
            }
            
            /// Check whether the given premium is valid.
            internal static func isValid(_ measurement: Decimal) -> Bool {
                return measurement.isNormal && !measurement.isSignMinus
            }
        }
    }
}

// MARK: Keyed Decoder

extension KeyedDecodingContainer {
    /// Decodes a stop level value for the given keys, if present.
    /// - parameter type: The type of value to decode.
    /// - parameter levelKey: The key that the stop level value is associated with.
    /// - parameter distanceKey: The key that the stop distance value is associated with.
    /// - parameter isGuaranteedKey: The key that the guaranteed stop value is associated with.
    /// - parameter trailingDistanceKey: The key that the trailing distance value is associated with.
    /// - parameter trailingIncrementKey: The key that the trailing increment value is associated with.
    /// - parameter referencing: The deal direction and level given where the stop will apply.
    /// - returns: A decoded value of deal stop type, or `nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value.
    /// - throws: `DecodingError` exclusively.
    internal func decodeIfPresent(_ type: IG.Deal.Stop.Type, forLevelKey levelKey: KeyedDecodingContainer<K>.Key?, distanceKey: KeyedDecodingContainer<K>.Key?,
                                  riskKey: (isGuaranteed: KeyedDecodingContainer<K>.Key, premium: KeyedDecodingContainer<K>.Key?),
                                  trailingKey: (isActive: KeyedDecodingContainer<K>.Key?, distance: KeyedDecodingContainer<K>.Key?, increment: KeyedDecodingContainer<K>.Key?)) throws -> IG.Deal.Stop? {
        typealias S = IG.Deal.Stop
        
        let stop: (level: Decimal?, distance: Decimal?) = (
            try levelKey.flatMap { try self.decodeIfPresent(Decimal.self, forKey: $0) },
            try distanceKey.flatMap { try self.decodeIfPresent(Decimal.self, forKey: $0) }
        )
        if case (.none, .none) = stop { return nil }
        
        let risk: S.Risk = try {
            guard try self.decode(Bool.self, forKey: riskKey.isGuaranteed) else { return .exposed }
            let premium = try riskKey.premium.flatMap { try self.decodeIfPresent(Decimal.self, forKey: $0) }
            return .limited(premium: premium)
        }()
        
        let trailing: S.Trailing = try {
            let distance  = try trailingKey.distance.flatMap  { try self.decodeIfPresent(Decimal.self, forKey: $0) }
            let increment = try trailingKey.increment.flatMap { try self.decodeIfPresent(Decimal.self, forKey: $0) }
            let existance = try trailingKey.isActive.flatMap  { try self.decodeIfPresent(Bool.self, forKey: $0) } ?? (distance != nil && increment != nil)
            switch (existance, distance, increment) {
            case (false, .none, .none):
                return .static
            case (true, .none, .none):
                return .dynamic(nil)
            case (true, let d?, let i?):
                guard case .exposed = risk else {
                    let msg = #"The decoded stop is indicated as both trailing and limited risk. IG doesn't allow trailing stops to be "guaranteed stops"."#
                    throw DecodingError.dataCorruptedError(forKey: riskKey.isGuaranteed, in: self, debugDescription: msg)
                }
                return .dynamic(.init(distance: d, increment: i))
            case (_, let d?, .none):
                let msg = #"A stop trailing distance was decoded "\#(d)", but a stop trailing increment was not found for key "\#(trailingKey.distance!.stringValue)". Both must be set or be nil at the same time."#
                throw DecodingError.dataCorruptedError(forKey: trailingKey.distance!, in: self, debugDescription: msg)
            case (_, .none, let i?):
                let msg = #"A stop trailing increment was decoded "\#(i)", but a stop trailing distance was not found for key "\#(trailingKey.increment!.stringValue)". Both must be set or be nil at the same time."#
                throw DecodingError.dataCorruptedError(forKey: trailingKey.increment!, in: self, debugDescription: msg)
            case (false, let d?, let i?):
                let msg = #"The stop is indicated as "not trailing", but there are trailing stop distance "\#(d)" and increment "\#(i)"."#
                throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: msg))
            }
        }()
        
        switch stop {
        case (.none, let distance?):
            return try S.distance(distance, risk: risk, trailing: trailing)
                ?! DecodingError.dataCorruptedError(forKey: distanceKey!, in: self, debugDescription: #"The stop distance "\#(distance)" decoded is not valid with the decoded risk "\#(risk)" and trailing "\#(trailing)"."#)
        case (let level?, .none):
            return try S.position(level: level, risk: risk, trailing: trailing)
                ?! DecodingError.dataCorruptedError(forKey: levelKey!, in: self, debugDescription: #"The stop level "\#(level)" decoded is not valid with the decoded risk "\#(risk)" and trailing "\#(trailing)"."#)
        case (let level?, let distance?):
            var possibleStop: S? = nil
            // Whole numbers are prefered as distances.
            if let stop = S.distance(distance, risk: risk, trailing: trailing) {
                if distance.isWhole {
                    return stop
                }
                possibleStop = stop
            }
            
            if let stop = S.position(level: level, risk: risk, trailing: trailing) {
                return stop
            }
            
            guard let stop = possibleStop else {
                let msg = #"The stop level "\#(level)" and/or the stop distance "\#(distance)" decoded were invalid."#
                throw DecodingError.dataCorruptedError(forKey: levelKey!, in: self, debugDescription: msg)
            }
            return stop
        case (.none, .none):
            return nil
        }
    }
}

extension IG.Deal.Stop: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = "Stop "
        
        switch self.type {
        case .position(let level): result.append("position at \(level)")
        case .distance(let dista): result.append("distance of \(dista) pips")
        }
        
        switch self.risk {
        case .exposed: result.append(" exposed to closing risk")
        case .limited(let premium?): result.append(" with limited closing risk exposure (premium: \(premium)")
        case .limited(premium: nil): result.append(" with limited closing risk exposure")
        }
        
        switch self.trailing {
        case .static: result.append(".")
        case .dynamic(let settings?): result.append(" and trailing (distance: \(settings.distance), increment: \(settings.increment)).")
        case .dynamic(nil): result.append(" and trailing.")
        }
        
        return result
    }
}
