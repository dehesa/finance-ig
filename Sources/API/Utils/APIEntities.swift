import Foundation

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

extension API.Instrument {
    /// The point when a trading position automatically closes is known as the expiry date (or expiration date).
    ///
    /// Expiry dates can vary from product to product. Spread bets, for example, always have a fixed expiry date. CFDs do not, unless they are on futures, digital 100s or options.
    public enum Expiry: ExpressibleByNilLiteral, Codable, Equatable {
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
                if let date = API.TimeFormatter.dayMonthYear.date(from: string) {
                    self = .forward(date)
                } else if let date = API.TimeFormatter.monthYear.date(from: string) {
                    self = .forward(date.lastDayOfMonth)
                } else if let date = API.TimeFormatter.iso8601NoTimezone.date(from: string) {
                    self = .forward(date)
                } else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: API.TimeFormatter.dayMonthYear.parseErrorLine(date: string))
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
                let formatter = (date.isLastDayOfMonth) ? API.TimeFormatter.monthYear : API.TimeFormatter.dayMonthYear
                try container.encode(formatter.string(from: date))
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case dfb = "DFB"
            case none = "-"
        }
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
        public let bid: Decimal?
        /// The price being asked (to sell an asset).
        public let ask: Decimal?
        /// Lowest price of the day.
        public let lowest: Decimal
        /// Highest price of the day.
        public let highest: Decimal
        /// Net and percentage change price on that day.
        public let change: (net: Decimal, percentage: Decimal)
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.bid = try container.decodeIfPresent(Decimal.self, forKey: .bid)
            self.ask = try container.decodeIfPresent(Decimal.self, forKey: .ask)
            self.lowest = try container.decode(Decimal.self, forKey: .lowest)
            self.highest = try container.decode(Decimal.self, forKey: .highest)
            self.change = (
                try container.decode(Decimal.self, forKey: .netChange),
                try container.decode(Decimal.self, forKey: .percentageChange)
            )
        }
        
        private enum CodingKeys: String, CodingKey {
            case bid, ask = "offer"
            case lowest = "low"
            case highest = "high"
            case netChange, percentageChange
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
        /// Exchange identifier for the instrument.
        public let exchangeIdentifier: String?
        /// Instrument name.
        public let name: String
        /// Instrument type.
        public let type: API.Instrument
        /// Instrument expiry period.
        public let expiry: API.Instrument.Expiry
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
            self.exchangeIdentifier = try container.decodeIfPresent(String.self, forKey: .exchangeId)
            self.name = try container.decode(String.self, forKey: .name)
            self.type = try container.decode(API.Instrument.self, forKey: .type)
            self.expiry = try container.decodeIfPresent(API.Instrument.Expiry.self, forKey: .expiry) ?? .none
            self.lotSize = try container.decodeIfPresent(UInt.self, forKey: .lotSize)
            self.isAvailableByStreaming = try container.decode(Bool.self, forKey: .isAvailableByStreaming)
            self.isOTCTradeable = try container.decodeIfPresent(Bool.self, forKey: .isOTCTradeable)
        }
        
        private enum CodingKeys: String, CodingKey {
            case epic, exchangeId
            case name = "instrumentName"
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
        public let delay: TimeInterval
        /// Describes the current status of a given market
        public let status: API.Market.Status
        /// The state of the market price at the time of the snapshot.
        public let price: API.Market.Price
        /// Multiplying factor to determine actual pip value for the levels used by the instrument.
        public let scalingFactor: Decimal
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            let responseDate = decoder.userInfo[API.JSON.DecoderKey.responseDate] as? Date ?? Date()
            let timeDate = try container.decode(Date.self, forKey: .lastUpdate, with: API.TimeFormatter.time)
            let update = try responseDate.mixComponents([.year, .month, .day], withDate: timeDate, [.hour, .minute, .second], calendar: UTC.calendar, timezone: UTC.timezone) ?!
                DecodingError.dataCorruptedError(forKey: .lastUpdate, in: container, debugDescription: "The update time couldn't be inferred.")
            
            if update > responseDate {
                let newDate = try UTC.calendar.date(byAdding: DateComponents(day: -1), to: update) ?!
                    DecodingError.dataCorruptedError(forKey: .lastUpdate, in: container, debugDescription: "Error processing update time.")
                self.date = newDate
            } else {
                self.date = update
            }
            
            self.delay = try container.decode(TimeInterval.self, forKey: .delay)
            self.status = try container.decode(API.Market.Status.self, forKey: .status)
            self.price = try .init(from: decoder)
            self.scalingFactor = try container.decode(Decimal.self, forKey: .scalingFactor)
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
        case limit(level: Decimal)
        /// Quote orders get executed at the specified level.
        ///
        /// The level has to be accompanied by a valid quote id (i.e. Lightstreamer price quote identifier).
        ///
        /// A quoteID is the two-way market price that we are making for a given instrument. Because it is two-way, you can 'buy' or 'sell', according to whether you think the price will rise or fall
        /// - note: This type is only available subject to agreement with IG.
        case quote(id: String, level: Decimal)
        
        /// Returns the level for the order if it is known.
        var level: Decimal? {
            switch self {
            case .market: return nil
            case .limit(let level): return level
            case .quote(_, let level): return level
            }
        }
        
        /// The order fill strategy.
        public enum Strategy: String, Encodable {
            /// Execute and eliminate.
            case execute = "EXECUTE_AND_ELIMINATE"
            /// Fill or kill.
            case fillOrKill = "FILL_OR_KILL"
        }
    }
}

extension API.WorkingOrder {
    /// Working order type.
    public enum Kind: String, Codable {
        /// An instruction to deal if the price moves to a more favourable level.
        ///
        /// This is an order to open a position by buying when the market reaches a lower level than the current price, or selling short when the market hits a higher level than the current price.
        /// This is suitable if you think the market price will **change direction** when it hits a certain level.
        case limit = "LIMIT"
        /// This is an order to buy when the market hits a higher level than the current price, or sell when the market hits a lower level than the current price.
        /// This is suitable if you think the market will continue **moving in the same direction** once it hits a certain level.
        case stop = "STOP"
    }
    
    /// Describes when the working order will expire.
    public enum Expiration {
        /// The order remains in place till it is explicitly cancelled.
        case tillCancelled
        /// The order remains in place till it is fulfill or the associated date is reached.
        case tillDate(Date)
        
        internal enum CodingKeys: String {
            case tillCancelled = "GOOD_TILL_CANCELLED"
            case tillDate = "GOOD_TILL_DATE"
        }
    }
}
