import Decimals

extension Deal {
    /// The level/price at which the user doesn't want to incur more lose.
    public struct Stop: Hashable {
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

extension Deal.Stop {
    /// Available types of stops.
    public enum Kind: Hashable {
        /// Absolute value of the stop (e.g. 1.653 USD/EUR).
        /// - parameter level: The stop absolute level.
        case position(level: Decimal64)
        /// Relative stop over an undisclosed reference level.
        case distance(Decimal64)
    }

    /// Defines the amount of risk being exposed while closing the stop loss.
    public enum Risk: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral, Hashable {
        /// A guaranteed stop is a stop-loss order that puts an absolute limit on your liability, eliminating the chance of slippage and guaranteeing an exit price for your trade.
        /// - parameter premium: The number of pips that are being charged for your limited risk (i.e. guaranteed stop).
        case limited(premium: Decimal64? = nil)
        /// An exposed (or non-guaranteed) stop may expose the trade to slippage when exiting it.
        case exposed
    }

    /// A distance from the buy/sell level which will be moved towards the current level in case of a favourable trade.
    public enum Trailing: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral, Hashable {
        /// A static (non-movable) stop.
        case `static`
        /// A dynamic (trailing) stop.
        case `dynamic`(Self.Settings? = nil)
        
        /// The trailing settings (i.e. trailing distance and trailing increment/step).
        public struct Settings: Equatable, Hashable {
            /// The distance from the  market price.
            public let distance: Decimal64
            /// The stop level increment step in pips.
            public let increment: Decimal64
            
            fileprivate init(distance: Decimal64, increment: Decimal64) { self.distance = distance; self.increment = increment }
        }
    }
}

// MARK: - Factories

extension Deal.Stop {
    /// Creates a stop level based on an absolute level value.
    ///
    /// A guaranteed stop pays an extra premium (indicated by the server).
    /// - parameter level: The absolute level value at which the stop will be.
    /// - parameter isStopGuaranteed: Indicates when at the stop activation time, the filling risk is limited or exposed.
    public static func position(level: Decimal64, isStopGuaranteed: Bool = false) -> Self {
        self.init(.position(level: level), risk: (isStopGuaranteed) ? .limited(premium: nil) : .exposed, trailing: .static)
    }
    
    /// Creates a stop level based on an absolute level value.
    ///
    /// A guaranteed stop pays an extra premium (indicated by the server).
    /// - parameter level: The absolute level value at which the stop will be.
    /// - parameter risk: Indicates, when the stop is activitated, whether the filling risk is exposed or limited (with the exact risk premium).
    /// - parameter trailing: Indicates whether the stop should be dynamic (i.e. trailing) or static (i.e. not trailing).
    internal static func position(level: Decimal64, risk: Self.Risk, trailing: Self.Trailing) -> Self? {
        if case .limited(let premium?) = risk, premium < 0 { return nil }
        if case .dynamic(let settings?) = trailing, (settings.distance <= 0) || (settings.increment <= 0) { return nil }
        return self.init(.position(level: level), risk: risk, trailing: trailing)
    }
    
    /// Creates a stop level based on an absolute level value.
    ///
    /// A guaranteed stop pays an extra premium (indicated by the server).
    /// - parameter level: The absolute level value at which the stop will be.
    /// - parameter risk: Indicates, when the stop is activitated, whether the filling risk is exposed or limited (with the exact risk premium).
    /// - parameter trailing: Indicates whether the stop should be dynamic (i.e. trailing) or static (i.e. not trailing).
    /// - parameter direction: The deal direction.
    /// - parameter base: The deal/base level.
    internal static func position(level: Decimal64, risk: Self.Risk, trailing: Self.Trailing, _ direction: Deal.Direction, from base: Decimal64) -> Self? {
        guard Self.isValid(level: level, direction, from: base) else { return nil }
        if case .limited(let premium?) = risk, premium < 0 { return nil }
        if case .dynamic(let settings?) = trailing, (settings.distance <= 0) || (settings.increment <= 0) { return nil }
        return self.init(.position(level: level), risk: risk, trailing: trailing)
    }
    
    /// Creates a stop level based on a relative distince from the base level (not specified here).
    ///
    /// A guaranteed stop pays an extra premium (indicated by the server).
    /// - parameter distance: A positive number which will get added or substracted from the base level depending on the direction of the deal.
    /// - parameter isStopGuaranteed: Indicates, when the stop is activited, whether the filling risk is limited or exposed.
    public static func distance(_ distance: Decimal64, isStopGuaranteed: Bool = false) -> Self {
        self.init(.distance(distance), risk: (isStopGuaranteed) ? .limited(premium: nil) : .exposed, trailing: .static)
    }
    
    /// Creates a stop level based on a relative distince from the base level (not specified here).
    ///
    /// A guaranteed stop pays an extra premium (indicated by the server).
    /// - parameter distance: A positive number which will get added or substracted from the base level depending on the direction of the deal.
    /// - parameter risk: Indicates, when the stop is activitated, whether the filling risk is exposed or limited (with the exact risk premium).
    /// - parameter trailing: Indicates whether the stop should be dynamic (i.e. trailing) or static (i.e. not trailing).
    internal static func distance(_ distance: Decimal64, risk: Self.Risk, trailing: Self.Trailing) -> Self? {
        if case .limited(let premium?) = risk, premium < 0 { return nil }
        if case .dynamic(let settings?) = trailing, (settings.distance <= 0) || (settings.increment <= 0) { return nil }
        return self.init(.distance(distance), risk: risk, trailing: trailing)
    }
    
    /// Creates a stop level based on a relative distince from the base level (not specified here).
    ///
    /// A guaranteed stop pays an extra premium (indicated by the server).
    /// - parameter distance: A positive number which will get added or substracted from the base level depending on the direction of the deal.
    /// - parameter increment: The increment/steps taken everytime the deals go in your favor and the distance from the base level is smaller than `distance`.
    /// - parameter isStopGuaranteed: Indicates when at the stop activation time, the filling risk is limited or exposed.
    public static func trailing(_ distance: Decimal64, increment: Decimal64) -> Self? {
        guard distance > 0, increment > 0 else { return nil }
        return self.init(.distance(distance), risk: .exposed, trailing: .dynamic(.init(distance: distance, increment: increment)))
    }
}

extension Deal.Stop.Risk {
    @_transparent public init(nilLiteral: ()) {
        self = .exposed
    }
    
    @_transparent public init(booleanLiteral value: Bool) {
        self = (value) ? .exposed : .limited(premium: nil)
    }
}

extension Deal.Stop.Trailing {
    @_transparent public init(nilLiteral: ()) {
        self = .static
    }
    
    @_transparent public init(booleanLiteral value: Bool) {
        self = (value) ? .dynamic(nil) : .static
    }
}

// MARK: - Functionality

extension Deal.Stop: CustomDebugStringConvertible {
    /// Returns the absolute stop level.
    /// - parameter direction: The deal direction.
    /// - parameter base: The deal/base level.
    public func level(_ direction: Deal.Direction, from base: Decimal64) -> Decimal64? {
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
    public func distance(_ direction: Deal.Direction, from base: Decimal64) -> Decimal64? {
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
    
    /// Checks that the given level is finite and lower than the base level on a `.buy` direction and greater than the base level on a `.sell` direction.
    /// - parameter level: The stop level.
    /// - parameter direction: The deal direction.
    /// - parameter base: The deal/base level.
    private static func isValid(level: Decimal64, _ direction: Deal.Direction, from base: Decimal64) -> Bool {
        switch direction {
        case .buy:  return level < base
        case .sell: return level > base
        }
    }
    
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
        case .dynamic(let settings?): result.append(" and trailing (distance: \(settings.distance), increment: \(settings.increment))")
        case .dynamic(nil): result.append(" and trailing")
        }
        
        return result
    }
}

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
    internal func decodeIfPresent(_ type: Deal.Stop.Type, forLevelKey levelKey: KeyedDecodingContainer<K>.Key?, distanceKey: KeyedDecodingContainer<K>.Key?,
                                  riskKey: (isGuaranteed: KeyedDecodingContainer<K>.Key, premium: KeyedDecodingContainer<K>.Key?),
                                  trailingKey: (isActive: KeyedDecodingContainer<K>.Key?, distance: KeyedDecodingContainer<K>.Key?, increment: KeyedDecodingContainer<K>.Key?)) throws -> Deal.Stop? {
        let stop: (level: Decimal64?, distance: Decimal64?) = (
             try levelKey.flatMap { try self.decodeIfPresent(Decimal64.self, forKey: $0) },
             try distanceKey.flatMap { try self.decodeIfPresent(Decimal64.self, forKey: $0) }
            )
        if case (.none, .none) = stop { return nil }

        let risk: Deal.Stop.Risk = try {
            guard try self.decode(Bool.self, forKey: riskKey.isGuaranteed) else { return .exposed }
            let premium = try riskKey.premium.flatMap { try self.decodeIfPresent(Decimal64.self, forKey: $0) }
            return .limited(premium: premium)
        }()

        let trailing: Deal.Stop.Trailing = try {
            let distance  = try trailingKey.distance.flatMap  { try self.decodeIfPresent(Decimal64.self, forKey: $0) }
            let increment = try trailingKey.increment.flatMap { try self.decodeIfPresent(Decimal64.self, forKey: $0) }
            let existance = try trailingKey.isActive.flatMap  { try self.decodeIfPresent(Bool.self, forKey: $0) } ?? (distance != nil && increment != nil)
            switch (existance, distance, increment) {
            case (false, .none, .none):
                return .static
            case (true, .none, .none):
                return .dynamic(nil)
            case (true, let d?, let i?):
                guard case .exposed = risk else {
                    let msg = "The decoded stop is indicated as both trailing and limited risk. IG doesn't allow trailing stops to be 'guaranteed stops'"
                    throw DecodingError.dataCorruptedError(forKey: riskKey.isGuaranteed, in: self, debugDescription: msg)
                }
                return .dynamic(.init(distance: d, increment: i))
            case (_, let d?, .none):
                let key = trailingKey.distance ?! fatalError()
                let msg = "A stop trailing distance was decoded '\(d), but a stop trailing increment was not found for key '\(key.stringValue)'. Both must be set or be nil at the same time"
                throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: msg)
            case (_, .none, let i?):
                let key = trailingKey.increment ?! fatalError()
                let msg = "A stop trailing increment was decoded '\(i)', but a stop trailing distance was not found for key '\(key.stringValue)'. Both must be set or be nil at the same time"
                throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: msg)
            case (false, let d?, let i?):
                let msg = "The stop is indicated as 'not trailing', but there are trailing stop distance '\(d)' and increment '\(i)'"
                throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: msg))
            }
        }()

        switch stop {
        case (.none, let distance?):
            guard let stop = Deal.Stop.distance(distance, risk: risk, trailing: trailing) else {
                let key = distanceKey ?! fatalError()
                throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "The stop distance '\(distance)' decoded is not valid with the decoded risk '\(risk)' and trailing '\(trailing)'")
            }
            return stop
        case (let level?, .none):
            guard let stop = Deal.Stop.position(level: level, risk: risk, trailing: trailing) else {
                let key = levelKey ?! fatalError()
                throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "The stop level '\(level)' decoded is not valid with the decoded risk '\(risk)' and trailing '\(trailing)'")
            }
            return stop
        case (let level?, let distance?):
            var possibleStop: Deal.Stop? = nil
            if let stop = Deal.Stop.distance(distance, risk: risk, trailing: trailing) {
                if distance.decomposed().fractional.isZero { return stop }
                possibleStop = stop
            }

            if let stop = Deal.Stop.position(level: level, risk: risk, trailing: trailing) { return stop }
            return try possibleStop ?> DecodingError.dataCorruptedError(forKey: levelKey ?! fatalError(), in: self, debugDescription: "The stop level '\(level)' and/or the stop distance '\(distance)' decoded were invalid")
        case (.none, .none):
            return nil
        }
    }
}
