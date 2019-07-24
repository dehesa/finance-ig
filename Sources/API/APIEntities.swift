import Foundation

extension API {
    /// The point when a trading position automatically closes is known as the expiry date (or expiration date).
    ///
    /// Expiry dates can vary from product to product. Spread bets, for example, always have a fixed expiry date. CFDs do not, unless they are on futures, digital 100s or options.
    public enum Expiry: Codable, ExpressibleByNilLiteral {
        /// DFBs (i.e. "Daily Funded Bets") run for as long as you choose to keep them open, with a default expiry some way off in the future.
        ///
        /// The cost of maintaining your DFB position is levied on your account each day: hence daily funded bet. You would generally use a daily funded bet to speculate on short-term market movements.
        case dailyFunded
        /// Forward bets will expire after a set period; instead of paying each day to keep the position open, the entire cost is taken into account in the spread.
        case forward(Date)
        /// No expiration date required.
        case none
        
        public init(nilLiteral: ()) {
            self = .none
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            guard !container.decodeNil() else {
                self = .none; return
            }
            
            let string = try container.decode(String.self)
            switch string {
            case Self.CodingKeys.none.rawValue:
                self = .none
            case Self.CodingKeys.dfb.rawValue, Self.CodingKeys.dfb.rawValue.lowercased():
                self = .dailyFunded
            default:
                if let date = API.DateFormatter.dayMonthYear.date(from: string) {
                    self = .forward(date)
                } else if let date = API.DateFormatter.monthYear.date(from: string) {
                    self = .forward(date.lastDayOfMonth)
                } else if let date = API.DateFormatter.iso8601NoTimezone.date(from: string) {
                    self = .forward(date)
                } else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: API.DateFormatter.dayMonthYear.parseErrorLine(date: string))
                }
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .none:
                try container.encode(Self.CodingKeys.none.rawValue)
            case .dailyFunded:
                try container.encode(Self.CodingKeys.dfb.rawValue)
            case .forward(let date):
                let formatter = (date.isLastDayOfMonth) ? API.DateFormatter.monthYear : API.DateFormatter.dayMonthYear
                try container.encode(formatter.string(from: date))
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case dfb = "DFB"
            case none = "-"
        }
    }
}

extension API {
    /// Instrument related entities.
    public enum Instrument: String, Codable {
        /// A binary allows you to take a view on whether a specific outcome will or won't occur. For example, 'Will Wall Street be up at the close of the day?' If the answer is 'yes', the binary settles at 100. If the answer is 'no', the binary settles at 0. Your profit or loss is the difference between 100 (if the event occurs) or zero (if the event doesn't occur) and the level at which you 'bought' or 'sold'. Binary prices can be extremely volatile even when the underlying market is relatively static. A small movement in the underlying can make all the difference between the binary settling at 0 or 100.
        case binary = "BINARY"
        case bungeeCapped  = "BUNGEE_CAPPED"
        case bungeeCommodities  = "BUNGEE_COMMODITIES"
        case bungeeCurrencies = "BUNGEE_CURRENCIES"
        case bungeeIndices = "BUNGEE_INDICES"
        case commodities = "COMMODITIES"
        case currencies = "CURRENCIES"
        case indices = "INDICES"
        case optCommodities = "OPT_COMMODITIES"
        case optCurrencies = "OPT_CURRENCIES"
        case optIndices = "OPT_INDICES"
        case optRates = "OPT_RATES"
        case optShares = "OPT_SHARES"
        case rates = "RATES"
        case sectors = "SECTORS"
        case shares = "SHARES"
        case sprintMarket = "SPRINT_MARKET"
        case testMarket = "TEST_MARKET"
        case unknown = "UNKNOWN"
    }
}

extension API.Market {
    /// The current status of the market.
    public enum Status: String, Codable {
        /// The market is open for trading.
        case tradeable = "TRADEABLE"
        /// The market is closed for the moment. Look at the market's opening hours for further information.
        case closed = "CLOSED"
        case editsOnly = "EDITS_ONLY"
        case onAuction = "ON_AUCTION"
        case onAuctionNoEdits = "ON_AUCTION_NO_EDITS"
        case offline = "OFFLINE"
        /// The market is suspended for trading temporarily.
        case suspended = "SUSPENDED"
    }
    
    /// Market's price at a snapshot's time.
    public struct Price: Decodable {
        /// The price being offered (to buy an asset).
        public let bid: Double?
        /// The price being asked (to sell an asset).
        public let offer: Double?
        /// Lowest price of the day.
        public let lowest: Double
        /// Highest price of the day.
        public let highest: Double
        /// Net change price on that day.
        public let changeNet: Double
        /// Percentage change price on that day.
        public let changePercentage: Double
        
        private enum CodingKeys: String, CodingKey {
            case bid, offer
            case lowest = "low"
            case highest = "high"
            case changeNet = "netChange"
            case changePercentage = "percentageChange"
        }
    }
    
    /// Distance/Size preference.
    public struct Distance: Decodable {
        /// The distance value.
        public let value: Double
        /// The unit at which the `value` is measured against.
        public let unit: Unit
        
        public enum Unit: String, Decodable {
            case points = "POINTS"
            case percentage = "PERCENTAGE"
        }
    }
}

extension API.Node {
    /// Market data hanging from a hierarchical node.
    public struct Market: Decodable {
        /// The market's instrument.
        public let instrument: Self.Instrument
        /// The market's prices.
        public let snapshot: Self.Snapshot
        
        public init(from decoder: Decoder) throws {
            self.instrument = try .init(from: decoder)
            self.snapshot = try .init(from: decoder)
        }
    }
}

extension API.Node.Market {
    /// Market's instrument properties.
    public struct Instrument: Decodable {
        /// Instrument epic identifier.
        public let epic: Epic
        /// Instrument name.
        public let name: String
        /// Instrument type.
        public let type: API.Instrument
        /// Instrument expiry period.
        public let expiry: API.Expiry
        /// Minimum amount of unit that an instrument can be dealt in the market. It's the relationship between unit and the amount per point.
        /// - note: This property is set when querying nodes, but `nil` when querying markets.
        public let lotSize: UInt?
        /// `true` if streaming prices are available, i.e. the market is tradeable and the client holds the necessary access permission.
        public let isAvailableByStreaming: Bool
        /// `true` if Over-The-Counter tradeable.
        /// - note: This property is set when querying nodes, but `nil` when querying markets.
        public let isOTCTradeable: Bool?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.epic = try container.decode(Epic.self, forKey: .epic)
            self.name = try container.decode(String.self, forKey: .name)
            self.type = try container.decode(API.Instrument.self, forKey: .type)
            self.expiry = try container.decodeIfPresent(API.Expiry.self, forKey: .expiry) ?? .none
            self.lotSize = try container.decodeIfPresent(UInt.self, forKey: .lotSize)
            self.isAvailableByStreaming = try container.decode(Bool.self, forKey: .isAvailableByStreaming)
            self.isOTCTradeable = try container.decodeIfPresent(Bool.self, forKey: .isOTCTradeable)
        }
        
        private enum CodingKeys: String, CodingKey {
            case epic, name = "instrumentName"
            case type = "instrumentType"
            case expiry, lotSize
            case isAvailableByStreaming = "streamingPricesAvailable"
            case isOTCTradeable = "otcTradeable"
        }
    }
}

extension API.Node.Market {
    /// A snapshot of the state of a market.
    public struct Snapshot: Decodable {
        /// Time of the last price update.
        /// - attention: Although a full date is given, only the hours:minutes:seconds are meaningful.
        public let date: Date
        /// Pirce delay marked in minutes.
        public let delay: Double
        /// Describes the current status of a given market
        public let status: API.Market.Status
        /// The state of the market price at the time of the snapshot.
        public let price: API.Market.Price
        /// Multiplying factor to determine actual pip value for the levels used by the instrument.
        public let scalingFactor: Double
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            let responseDate = decoder.userInfo[API.JSON.DecoderKey.responseDate] as? Date ?? Date()
            let timeDate = try container.decode(Date.self, forKey: .lastUpdate, with: API.DateFormatter.time)
            
            guard let update = responseDate.mixComponents([.year, .month, .day], withDate: timeDate, [.hour, .minute, .second], calendar: UTC.calendar, timezone: UTC.timezone) else {
                throw DecodingError.dataCorruptedError(forKey: .lastUpdate, in: container, debugDescription: "The update time couldn't be inferred.")
            }
            
            if update > responseDate {
                guard let newDate = UTC.calendar.date(byAdding: DateComponents(day: -1), to: update) else {
                    throw DecodingError.dataCorruptedError(forKey: .lastUpdate, in: container, debugDescription: "Error processing update time.")
                }
                self.date = newDate
            } else {
                self.date = update
            }
            
            self.delay = try container.decode(Double.self, forKey: .delay)
            self.status = try container.decode(API.Market.Status.self, forKey: .status)
            self.price = try .init(from: decoder)
            self.scalingFactor = try container.decode(Double.self, forKey: .scalingFactor)
        }
        
        private enum CodingKeys: String, CodingKey {
            case lastUpdate = "updateTimeUTC"
            case delay = "delayTime"
            case status = "marketStatus"
            case scalingFactor
        }
    }
}


extension API.Position {
    /// Position's permanent identifier.
    public struct Identifier: RawRepresentable, Codable, ExpressibleByStringLiteral, Hashable {
        public let rawValue: String
        
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError("The deal identifier couldn't be identified or is not in the correct format.") }
            self.rawValue = value
        }
        
        public init?(rawValue: String) {
            guard Self.validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            guard Self.validate(rawValue) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "The given string doesn't conform to the regex pattern.")
            }
            self.rawValue = rawValue
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
        
        private static func validate(_ value: String) -> Bool {
            return (1...30).contains(value.count)
        }
    }
    
    /// Transient deal identifier (for an unconfirmed trade).
    public struct Reference: RawRepresentable, Codable, ExpressibleByStringLiteral, Hashable {
        public let rawValue: String
        /// The allowed character set.
        private static let allowedSet: CharacterSet = {
            var result = CharacterSet(arrayLiteral: "_", "-", #"\"#)
            result.formUnion(CharacterSet.Framework.lowercaseANSI)
            result.formUnion(CharacterSet.Framework.uppercaseANSI)
            result.formUnion(CharacterSet.decimalDigits)
            return result
        }()
        
        public init(stringLiteral value: String) {
            guard Self.validate(value) else { fatalError("The deal reference couldn't be identified or is not in the correct format.") }
            self.rawValue = value
        }
        
        public init?(rawValue: String) {
            guard Self.validate(rawValue) else { return nil }
            self.rawValue = rawValue
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            guard Self.validate(rawValue) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "The given string doesn't conform to the regex pattern.")
            }
            self.rawValue = rawValue
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
        
        private static func validate(_ value: String) -> Bool {
            let allowedRange = 1...30
            return allowedRange.contains(value.count) && value.unicodeScalars.allSatisfy { Self.allowedSet.contains($0) }
        }
    }
    
    /// Position status.
    public enum Status: Decodable {
        case open
        case amended
        case partiallyClosed
        case closed
        case deleted
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            switch value {
            case Self.CodingKeys.openA.rawValue, Self.CodingKeys.openB.rawValue: self = .open
            case Self.CodingKeys.amended.rawValue: self = .amended
            case Self.CodingKeys.partiallyClosed.rawValue: self = .partiallyClosed
            case Self.CodingKeys.closedA.rawValue, Self.CodingKeys.closedB.rawValue: self = .closed
            case Self.CodingKeys.deleted.rawValue: self = .deleted
            default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "The status value \"\(value)\" couldn't be parsed.")
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case openA = "OPEN", openB = "OPENED"
            case amended = "AMENDED"
            case partiallyClosed = "PARTIALLY_CLOSED"
            case closedA = "FULLY_CLOSED", closedB = "CLOSED"
            case deleted = "DELETED"
        }
    }
    
    /// Deal direction.
    public enum Direction: String, Codable {
        case buy = "BUY"
        case sell = "SELL"
        
        public var oppossite: Direction {
            switch self {
            case .buy:  return .sell
            case .sell: return .buy
            }
        }
    }
    
    /// Describes how the user's order must be executed.
    public enum Order {
        /// A market order is an instruction to buy or sell at the best available price for the size of your order.
        ///
        /// When using this type of order you choose the size and direction of your order, but not the price (a level cannot be specified).
        /// - note: Not applicable to BINARY instruments.
        case market
        /// A limit fill or kill order is an instruction to buy or sell in a specified size within a specified price limit, which is either filled completely or rejected.
        ///
        /// Provided the market price is within the specified limit and there is sufficient volume available, the order will be filled at the prevailing market price.
        ///
        /// The entire order will be rejected if:
        /// - The market price is outside your specified limit (higher for buy orders, lower for sell orders).
        /// - There is insufficient volume available to satisfy the full order size.
        case limit(level: Double)
        /// Quote orders get executed at the specified level.
        ///
        /// The level has to be accompanied by a valid quote id (i.e. Lightstreamer price quote identifier).
        ///
        /// A quoteID is the two-way market price that we are making for a given instrument. Because it is two-way, you can 'buy' or 'sell', according to whether you think the price will rise or fall
        /// - note: This type is only available subject to agreement with IG.
        case quote(id: String, level: Double)
        
        /// The order fill strategy.
        public enum Strategy: String, Encodable {
            /// Execute and eliminate.
            case execute = "EXECUTE_AND_ELIMINATE"
            /// Fill or kill.
            case fillOrKill = "FILL_OR_KILL"
        }
    }
    
    /// The level/price at which the user doesn't want to incur more lose.
    public enum Stop {
        /// Absolute value of the stop (e.g. 1.653 USD/EUR).
        /// - parameter level: The stop absolute level.
        /// - parameter risk: The risk exposed when exercising the stop loss.
        case position(level: Double, risk: Self.Risk)
        /// A distance from the buy/sell level stop with the tweak that the stop will be moved towards the current level in case of a favourable trade.
        /// - parameter distance: The distance from the buy/sell price.
        /// - parameter increment: The increment step in pips.
        case trailing(distance: Double, increment: Double)
        
        /// Defines the amount of risk being exposed while closing the stop loss.
        public enum Risk {
            /// A guaranteed stop is a stop-loss order that puts an absolute limit on your liability, eliminating the chance of slippage and guaranteeing an exit price for your trade.
            case limited(premium: Double? = nil)
            case exposed
        }
    }
}

//extension API {
//    /// Working order related entities.
//    public enum WorkingOrder {
//        /// The type of working order.
//        public enum Kind: String, Codable {
//            case limit = "LIMIT"
//            case stop = "STOP"
//        }
//        
//        /// Describes when the working order will expire.
//        public enum Expiration {
//            case tillCancelled
//            case tillDate(Date)
//            
//            /// Designated initializer to create an expiration for working orders.
//            /// - throws `Expiration.Error` if the raw value is invalid.
//            internal init(_ rawValue: String, date: Date?) throws {
//                switch rawValue {
//                case CodingKeys.tillCancelled.rawValue:
//                    self = .tillCancelled
//                case CodingKeys.tillDate.rawValue:
//                    guard let date = date else { throw Error.unavailableDate }
//                    self = .tillDate(date)
//                default:
//                    throw Error.invalidExpirationRawValue(rawValue)
//                }
//            }
//            
//            fileprivate enum Error: Swift.Error {
//                case invalidExpirationRawValue(String)
//                case unavailableDate
//            }
//            
//            internal var rawValue: String {
//                switch self {
//                case .tillCancelled: return CodingKeys.tillCancelled.rawValue
//                case .tillDate(_): return CodingKeys.tillDate.rawValue
//                }
//            }
//            
//            private enum CodingKeys: String {
//                case tillCancelled = "GOOD_TILL_CANCELLED"
//                case tillDate = "GOOD_TILL_DATE"
//            }
//        }
//        
//        /// Indicates the price for a given instrument.
//        public enum Boundary {
//            /// The type of limit being set.
//            public typealias Limit = API.Position.Boundary.Limit
//            
//            /// The level/price at which the user doesn't want to incur more lose.
//            public typealias Stop = Limit
//        }
//    }
//}
//
//extension APIPositionBoundaries {
//    /// Returns a boolean indicating whether there are no boundaries set.
//    public var isEmpty: Bool { return (self.limit == nil) && (self.stop == nil) }
//}

