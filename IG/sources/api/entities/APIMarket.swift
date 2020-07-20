import Foundation
import Decimals

extension API {
    /// A financial market, which may refer to an underlying financial market, or the market being offered in terms of an IG instrument.
    ///
    /// IG instruments are organised in the form a navigable market hierarchy
    public struct Market {
        /// The name of a natural grouping of a set of IG markets
        ///
        /// It typically represents the underlying 'real-world' market. For example, `VOD-UK` represents Vodafone Group PLC (UK).
        /// This identifier is primarily used in our market research services, such as client sentiment, and may be found on the /market/{epic} service
        public let identifier: String?
        /// IG tradeable financial instrument (market), typically based on some underlying financial market instrument.
        ///
        /// Since IG's instruments are derived, they do not have recognisable real-world identifiers such as the Reuters or Bloomberg codes.
        /// Instead, IGs instruments are identified by proprietary identifiers known as EPICs. `KA.D.VOD.CASH.IP`, for example, is the EPIC for IG’s Vodafone spot (as opposed to futures) instrument.
        ///
        /// The IG instrument EPICs for an underlying market of interest may be determined via our API’s set of /market services.
        /// - note:In the case of expiring time-based instruments, the IG instrument is 'rolled' over to the next interval, and so will represent a different underlying instrument, even though the EPIC is unchanged.
        public let instrument: Self.Instrument
        /// Market's dealing rules.
        public let rules: Self.Rules
        /// Market snapshot data.
        public let snapshot: Self.Snapshot
    }
}

extension API.Market {
    /// Instrument details.
    public struct Instrument {
        /// Instrument identifier.
        public let epic: IG.Market.Epic
        /// Instrument name.
        public let name: String
        /// Instrument type.
        public let type: Self.Kind
        /// Unit used to qualify the size of a trade.
        public let unit: Self.Unit
        /// Market expiration date details.
        public let expiration: Self.Expiration
        /// Country.
        public let country: String?
        /// Currencies.
        public let currencies: [Self.Currency]
        /// Market open and closes times.
        /// - todo: Not yet tested.
        public let openingTime: [Self.HourRange]?
        /// Meaning and value of the Price Interest Point (a.k.a. PIP).
        public let pip: Self.Pip?
        /// Minimum amount of unit that an instrument can be dealt in the market. It's the relationship between unit and the amount per point.
        public let lotSize: Decimal64
        /// Contract size.
        ///
        /// - For CFDs, this is the number of contracts you wish to trade or of open positions.
        /// - For spread bets this is the amount of profit or loss per point movement in the market
        public let contractSize: Decimal64?
        /// Boolean indicating whether "force open" is allowed.
        public let isForceOpenAllowed: Bool
        /// Boolean indicating whether stops and limits are allowed.
        public let isStopLimitAllowed: Bool
        /// Are controlled risk trades allowed.
        public let isLimitedRiskAllowed: Bool
        /// Boolean indicating whether prices are available through streaming communications.
        public let isAvailableByStreaming: Bool
        /// Deposit bands.
        public let margin: Self.Margin
        /// Slippage factor details for the given market.
        ///
        /// Slippage is the difference between the level of a stop order and the actual price at which it was executed.
        /// It can occur during periods of higher volatility when market prices move rapidly or gap
        public let slippageFactor: Self.SlippageFactor
        /// Where a trade or bet approaching expiry is closed and a position of the same size and direction is opened for the next period, thereby prolonging the exposure to a particular market
        public let rollover: Self.Rollover?
        /// The limited risk premium.
        public let limitedRiskPremium: API.Market.Distance
        /// Chart code.
        public let chartCode: String?
        /// Retuers news code.
        public let newsCode: String
        /// List of special information notices.
        public let details: [String]?
        /// Properties of sprint markets.
        public let sprintMarket: Self.SprintMarket?
    }
}

extension API.Market.Instrument {
    /// Instrument related entities.
    public enum Kind: Equatable {
        /// A binary allows you to take a view on whether a specific outcome will or won't occur.
        ///
        /// For example, Will Wall Street be up at the close of the day?
        /// - If the answer is 'yes', the binary settles at 100.
        /// - If the answer is 'no', the binary settles at 0.
        ///
        /// Your profit or loss is the difference between 100 (if the event occurs) or zero (if the event doesn't occur) and the level at which you 'bought' or 'sold'. Binary prices can be extremely volatile even when the underlying market is relatively static. A small movement in the underlying can make all the difference between the binary settling at 0 or 100.
        case binary
        case bungee(Self.Bungee)
        /// Commodities are hard assets ranging from wheat to gold to oil.
        case commodities
        /// Currencies are medium of exchange.
        case currencies
        /// An index is an statistical measure of change in a securities market.
        case indices
        /// An option is a contract which gives the buyer the right, but not the obligation, to buy or sell an underlying asset or instrument at a specified strike price prior to or on a specified date, depending on the form of the option.
        case options(Self.Options)
        /// Bonds, money markets, etc.
        case rates
        case sectors
        /// Shares are unit of ownership interest in a corporation or financial asset that provide for an equal distribution in any profits, if any are declared, in the form of dividends.
        case shares
        case sprintMarket
        case testMarket
        case unknown
        
        public enum Bungee: Equatable {
            case capped, commodities, currencies, indices
        }
        
        public enum Options: Equatable {
            case commodities, currencies, indices, rates, shares
        }
    }
    
    /// Expiration date details.
    public struct Expiration {
        /// Expiration date. The date (and sometimes time) at which a spreadbet or CFD will automatically close against some predefined market value should the bet remain open beyond its last dealing time. Some CFDs do not expire, and have an expiry of '-'. eg DEC-14, or DFB for daily funded bets.
        public let expiry: IG.Market.Expiry
        /// The last dealing date.
        public let lastDealingDate: Date?
        /// Settlement information.
        public let settlementInfo: String?
    }
    
    /// An instrument currency.
    public struct Currency {
        /// Symbol for display purposes.
        public let symbol: String
        /// Code to be used when placing orders.
        public let code: IG.Currency.Code
        /// Base exchange rate.
        public let baseExchangeRate: Decimal64
        /// Exchange rate.
        public let exchangeRate: Decimal64
        /// Is it the default currency?
        public let isDefault: Bool
    }
    
    /// Market open and close times.
    public struct HourRange {
        public let open: String
        public let close: String
    }
    
    /// Unit used to qualify the size of a trade.
    public enum Unit: String {
        case amount
        case contracts
        case shares
    }
    
    /// Market Pip (Price Interest Point).
    public struct Pip {
        /// What one pip actually signifies.
        public let meaning: String
        /// What is the value of one pip.
        public let value: String
    }
    
    /// Margin requirements and deposit bands.
    public struct Margin {
        /// Margin requirement factor.
        public let factor: Decimal64
        /// The dimension for the margin factor.
        public let unit: API.Market.Distance.Unit
        /// Deposit bands.
        public let depositBands: [Self.Band]
        
        public struct Band {
            /// The currency for this currency band factor calculation.
            public let currencyCode: IG.Currency.Code
            /// Margin percentage.
            public let margin: Decimal64
            /// Band minimum.
            public let minimum: Decimal64
            /// Band maximum.
            public let maximum: Decimal64?
        }
    }
    
    /// Distance/Size preference.
    public struct SlippageFactor {
        public let value: Decimal64
        public let unit: Unit
        
        public enum Unit: String {
            case percentage = "pct"
        }
    }
    
    /// Instrument rollover details.
    public struct Rollover {
        public let lastDate: Date
        public let info: String
    }
    
    /// Sprint market property.
    public struct SprintMarket {
        /// The minimum value to be specified as the expiration of a sprint markets trade.
        public let minExpirationDate: Date
        /// The maximum value to be specified as the expiration of a sprint markets trade.
        public let maxExpirationDate: Date
    }
}

extension API.Market {
    /// Dealing rule preferences.
    public struct Rules {
        /// Client's market order trading preference.
        ///
        /// An order that you use to specify the direction and size of a bet, but not the price.
        /// This ensures we will fill your order as quickly as possible, even if the price indicated on the deal ticket is not available for your requested order size
        public let marketOrder: Self.Order
        /// Minimum deal size.
        public let minimumDealSize: API.Market.Distance
        /// Rules for setting postions' limits.
        public let limit: Self.Limit
        /// Rules for setting positions' stops.
        public let stop: Self.Stop
        
        /// Market order trading preference.
        public enum Order {
            /// Market orders are not allowed for the current site and/or instrument.
            case unavailable
            /// Market orders are allowed for the account type and instrument and the user has enabled market orders in their preferences.
            /// The user has also decided whether that should be the default.
            case available(isDefault: Bool)
        }
        
        /// Settings for positions' limits.
        public struct Limit {
            /// Minimum normal limit distance.
            public let mininumDistance: API.Market.Distance
            /// Maximum limit distance.
            public let maximumDistance: API.Market.Distance
        }
        
        /// Settings for positions' stops.
        public struct Stop {
            /// Minimum normal stop distance.
            public let mininumDistance: API.Market.Distance
            /// Minimum controller risk stop distance.
            public let minimumLimitedRiskDistance: API.Market.Distance
            /// Maximum stop distance.
            public let maximumDistance: API.Market.Distance
            /// Trailing stops' settings.
            public let trailing: Self.Trailing
            
            /// Settings for positions' trailing stops.
            public struct Trailing {
                /// Trailing stops trading preference.
                public let areAvailable: Bool
                /// Minimum step distance.
                public let minimumIncrement: API.Market.Distance
            }
        }
    }
}

extension API.Market {
    /// Market snapshot data.
    public struct Snapshot {
        /// Time of the last price update.
        /// - attention: Although a full date is given, only the hours:minutes:seconds are meaningful.
        public let date: Date
        /// Pirce delay marked in minutes.
        public let delay: TimeInterval
        /// The current status of a given market
        public let status: API.Market.Status
        /// The state of the market price at the time of the snapshot.
        public let price: API.Market.Price?
        /// Multiplying factor to determine actual pip value for the levels used by the instrument.
        public let scalingFactor: Decimal64
        /// Number of decimal positions for market levels.
        public let decimalPlacesFactor: Int
        /// The number of points to add on each side of the market as an additional spread when placing a guaranteed stop trade.
        public let extraSpreadForControlledRisk: Decimal64
        /// Binary odds.
        public let binaryOdds: Decimal64?
    }
}

extension API.Market {
    /// The current status of the market.
    public enum Status {
        /// The market is open for trading.
        case tradeable
        /// The market is closed for the moment. Look at the market's opening hours for further information.
        case closed
        case editsOnly
        case onAuction
        case onAuctionNoEdits
        case offline
        /// The market is suspended for trading temporarily.
        case suspended
    }
}

extension API.Market {
    /// Market's price at a snapshot's time.
    public struct Price {
        /// The price being offered (to buy an asset).
        public let bid: Decimal64?
        /// The price being asked (to sell an asset).
        public let ask: Decimal64?
        /// Lowest price of the day.
        public let lowest: Decimal64
        /// Highest price of the day.
        public let highest: Decimal64
        /// Net and percentage change price on that day.
        public let change: (net: Decimal64, percentage: Decimal64)
        
        /// The middle price between the *bid* and the *ask* price.
        @_transparent public var mid: Decimal64? {
            guard let bid = self.bid, let ask = self.ask else { return nil }
            return bid + Decimal64(5, power: -1)! * (ask - bid)
        }
    }
}

extension API.Market {
    /// Distance/Size preference.
    public struct Distance {
        /// The distance value.
        public let value: Decimal64
        /// The unit at which the `value` is measured against.
        public let unit: Unit
        
        public enum Unit {
            case points, percentage
        }
    }
}

// MARK: -

extension API.Market: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.instrument = try container.decode(Self.Instrument.self, forKey: .instrument)
        self.rules = try container.decode(Self.Rules.self, forKey: .rules)
        self.snapshot = try container.decode(Self.Snapshot.self, forKey: .snapshot)
        
        let instrumentContainer = try container.nestedContainer(keyedBy: _Keys._NestedKeys.self, forKey: .instrument)
        self.identifier = try (instrumentContainer).decodeIfPresent(String.self, forKey: .identifier)
    }
    
    private enum _Keys: String, CodingKey {
        case instrument, rules = "dealingRules", snapshot
        
        enum _NestedKeys: String, CodingKey {
            case identifier = "marketId"
        }
    }
}

extension API.Market.Instrument: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.epic = try container.decode(IG.Market.Epic.self, forKey: .epic)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(API.Market.Instrument.Kind.self, forKey: .type)
        self.unit = try container.decode(Self.Unit.self, forKey: .unit)
        self.expiration = try .init(from: decoder)
        self.country = try container.decodeIfPresent(String.self, forKey: .country)
        self.currencies = try container.decodeIfPresent(Array<Self.Currency>.self, forKey: .currencies) ?? []
        
        if let wrapper = try container.decodeIfPresent([String:Array<Self.HourRange>].self, forKey: .openingTime) {
            self.openingTime = try wrapper[_Keys.openingMarketTimes.rawValue]
                ?> DecodingError.dataCorruptedError(forKey: .openingTime, in: container, debugDescription: "Openning times wrapper key '\(_Keys.openingMarketTimes.rawValue)' was not found")
        } else {
            self.openingTime = nil
        }
        
        
        let pipMeaning = try container.decodeIfPresent(String.self, forKey: .pipMeaning)
        let pipValue = try container.decodeIfPresent(String.self, forKey: .pipValue)
        if let meaning = pipMeaning, let value = pipValue {
            self.pip = .init(meaning: meaning, value: value)
        } else if pipMeaning == nil, pipValue == nil {
            self.pip = nil
        } else {
            throw DecodingError.dataCorruptedError(forKey: .pipMeaning, in: container, debugDescription: "The pip definition is inconsistent")
        }
        
        self.lotSize = try container.decode(Decimal64.self, forKey: .lotSize)
        if let contractString = try container.decodeIfPresent(String.self, forKey: .contractSize) {
            self.contractSize = try Decimal64(contractString)
                ?> DecodingError.dataCorruptedError(forKey: .contractSize, in: container, debugDescription: "The contract size '\(contractString)' couldn't be parsed into a number")
        } else {
            self.contractSize = nil
        }
        self.isForceOpenAllowed = try container.decode(Bool.self, forKey: .isForceOpenAllowed)
        self.isLimitedRiskAllowed = try container.decode(Bool.self, forKey: .isLimitedRiskAllowed)
        self.isStopLimitAllowed = try container.decode(Bool.self, forKey: .isStopLimitAllowed)
        self.isAvailableByStreaming = try container.decode(Bool.self, forKey: .isAvailableByStreaming)
        self.margin = try .init(from: decoder)
        self.slippageFactor = try container.decode(Self.SlippageFactor.self, forKey: .slippageFactor)
        self.rollover = try container.decodeIfPresent(Self.Rollover.self, forKey: .rollover)
        self.limitedRiskPremium = try container.decode(API.Market.Distance.self, forKey: .limitedRiskPremium)
        self.chartCode = try container.decodeIfPresent(String.self, forKey: .chartCode)
        self.newsCode = try container.decode(String.self, forKey: .newsCode)
        let details = try container.decodeIfPresent([String].self, forKey: .details)
        self.sprintMarket = try SprintMarket(from: decoder)
        self.details = details.flatMap { (!$0.isEmpty) ? $0 : nil }
    }
    
    private enum _Keys: String, CodingKey {
        case epic, name, type, country, currencies
        case openingMarketTimes = "marketTimes"
        case unit, pipMeaning = "onePipMeans"
        case pipValue = "valueOfOnePip"
        case lotSize, contractSize, slippageFactor
        case isForceOpenAllowed = "forceOpenAllowed"
        case isLimitedRiskAllowed = "controlledRiskAllowed"
        case isStopLimitAllowed = "stopsLimitsAllowed"
        case rollover = "rolloverDetails"
        case limitedRiskPremium
        case openingTime = "openingHours"
        case isAvailableByStreaming = "streamingPricesAvailable"
        case chartCode, newsCode
        case details = "specialInfo"
    }
}

extension API.Market.Instrument.Kind: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "BINARY": self = .binary
        case "COMMODITIES": self = .commodities
        case "CURRENCIES": self = .currencies
        case "INDICES": self = .indices
        case "OPT_COMMODITIES": self = .options(.commodities)
        case "OPT_CURRENCIES": self = .options(.currencies)
        case "OPT_INDICES": self = .options(.indices)
        case "OPT_RATES": self = .options(.rates)
        case "OPT_SHARES": self = .options(.shares)
        case "RATES": self = .rates
        case "SECTORS": self = .sectors
        case "SHARES": self = .shares
        case "SPRINT_MARKET": self = .sprintMarket
        case "TEST_MARKET": self = .testMarket
        case "BUNGEE_CAPPED": self = .bungee(.capped)
        case "BUNGEE_COMMODITIES": self = .bungee(.commodities)
        case "BUNGEE_CURRENCIES": self = .bungee(.currencies)
        case "BUNGEE_INDICES": self = .bungee(.indices)
        case "UNKNOWN": self = .unknown
        case let value: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid instrument type '\(value)'.")
        }
    }
}

extension API.Market.Instrument.Expiration: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        
        self.expiry = try container.decodeIfPresent(IG.Market.Expiry.self, forKey: .expirationDate) ?? .none
        guard container.contains(.expirationDetails), !(try container.decodeNil(forKey: .expirationDetails)) else {
            self.settlementInfo = nil
            self.lastDealingDate = nil
            return
        }
        
        let nestedContainer = try container.nestedContainer(keyedBy: _Keys._NestedKeys.self, forKey: .expirationDetails)
        self.settlementInfo = try nestedContainer.decodeIfPresent(String.self, forKey: .settlementInfo)
        
        let formatter = try decoder.userInfo[API.JSON.DecoderKey.computedValues] as? DateFormatter
            ?> DecodingError.dataCorruptedError(forKey: .lastDealingDate, in: nestedContainer, debugDescription: "The date formatter supposed to be passed as user info couldn't be found")
        self.lastDealingDate = try nestedContainer.decodeIfPresent(Date.self, forKey: .lastDealingDate, with: formatter)
    }
    
    private enum _Keys: String, CodingKey {
        case expirationDate = "expiry"
        case expirationDetails = "expiryDetails"
        
        enum _NestedKeys: String, CodingKey {
            case settlementInfo, lastDealingDate = "lastDealingDate"
        }
    }
}

extension API.Market.Instrument.Currency: Decodable {}

extension API.Market.Instrument.HourRange: Decodable {
    private enum CodingKeys: String, CodingKey {
        case open = "openTime"
        case close = "closeTime"
    }
}

extension API.Market.Instrument.Unit: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "AMOUNT": self = .amount
        case "CONTRACTS": self = .contracts
        case "SHARES": self = .shares
        case let value: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid instrument unit '\(value)'.")
        }
    }
}

extension API.Market.Instrument.Pip: Decodable {}

extension API.Market.Instrument.Margin: Decodable {
    private enum CodingKeys: String, CodingKey {
        case factor = "marginFactor"
        case unit = "marginFactorUnit"
        case depositBands = "marginDepositBands"
    }
}

extension API.Market.Instrument.Margin.Band: Decodable {
    private enum CodingKeys: String, CodingKey {
        case currencyCode = "currency"
        case margin
        case minimum = "min"
        case maximum = "max"
    }
}

extension API.Market.Instrument.SlippageFactor: Decodable {}

extension API.Market.Instrument.SlippageFactor.Unit: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "pct": self = .percentage
        case let value: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid slippage factor unit '\(value)'.")
        }
    }
}

extension API.Market.Instrument.Rollover: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        guard let formatter = decoder.userInfo[API.JSON.DecoderKey.computedValues] as? DateFormatter else {
            throw DecodingError.dataCorruptedError(forKey: .lastDate, in: container, debugDescription: "The date formatter supposed to be passed as user info couldn't be found")
        }
        
        self.lastDate = try container.decode(Date.self, forKey: .lastDate, with: formatter)
        self.info = try container.decode(String.self, forKey: .info)
    }
    
    private enum _Keys: String, CodingKey {
        case lastDate = "lastRolloverTime"
        case info = "rolloverInfo"
    }
}

extension API.Market.Instrument.SprintMarket {
    public init?(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        
        switch (try container.decodeNil(forKey: .sprintMin), try container.decodeNil(forKey: .sprintMax)) {
        case (false, false): break
        case (true, true): return nil
        default: throw DecodingError.dataCorruptedError(forKey: .sprintMax, in: container, debugDescription: "Sprint market has an invalid min/max range")
        }
        
        self.minExpirationDate = try container.decode(Date.self, forKey: .sprintMin, with: DateFormatter.dateDenormalBroad)
        self.maxExpirationDate = try container.decode(Date.self, forKey: .sprintMax, with: DateFormatter.dateDenormalBroad)
    }
    
    private enum _Keys: String, CodingKey {
        case sprintMin = "sprintMarketsMinimumExpiryTime"
        case sprintMax = "sprintMarketsMaximumExpiryTime"
    }
}

extension API.Market.Rules: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.marketOrder = try container.decode(Self.Order.self, forKey: .marketOrder)
        self.minimumDealSize = try container.decode(API.Market.Distance.self, forKey: .minimumDealSize)
        self.limit = try .init(from: decoder)
        self.stop = try .init(from: decoder)
    }
    
    private enum _Keys: String, CodingKey {
        case marketOrder = "marketOrderPreference"
        case minimumDealSize = "minDealSize"
    }
}

/// Market order trading preference.
extension API.Market.Rules.Order: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "NOT_AVAILABLE": self = .unavailable
        case "AVAILABLE_DEFAULT_ON": self = .available(isDefault: false)
        case "AVAILABLE_DEFAULT_OFF": self = .available(isDefault: true)
        case let value: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid market rules order '\(value)'.")
        }
    }
}

extension API.Market.Rules.Limit: Decodable {
    private enum CodingKeys: String, CodingKey {
        case mininumDistance = "minNormalStopOrLimitDistance"
        case maximumDistance = "maxStopOrLimitDistance"
    }
}

extension API.Market.Rules.Stop: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.mininumDistance = try container.decode(API.Market.Distance.self, forKey: .mininumDistance)
        self.minimumLimitedRiskDistance = try container.decode(API.Market.Distance.self, forKey: .limitedRisk)
        self.maximumDistance = try container.decode(API.Market.Distance.self, forKey: .maximumDistance)
        self.trailing = try .init(from: decoder)
    }
    
    private enum _Keys: String, CodingKey {
        case mininumDistance = "minNormalStopOrLimitDistance"
        case limitedRisk = "minControlledRiskStopDistance"
        case maximumDistance = "maxStopOrLimitDistance"
    }
}

extension API.Market.Rules.Stop.Trailing: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.minimumIncrement = try container.decode(API.Market.Distance.self, forKey: .minimumIncrement)
        let trailingStops = try container.decode(_Values.self, forKey: .areTrailingStopsAvailable)
        self.areAvailable = trailingStops == .available
    }
    
    private enum _Keys: String, CodingKey {
        case minimumIncrement = "minStepDistance"
        case areTrailingStopsAvailable = "trailingStopsPreference"
    }
    
    private enum _Values: String, Decodable {
        case available = "AVAILABLE"
        case unavailable = "NOT_AVAILABLE"
    }
}

extension API.Market.Snapshot: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        
        guard let responseDate = decoder.userInfo[API.JSON.DecoderKey.responseDate] as? Date else {
            let ctx = DecodingError.Context(codingPath: container.codingPath, debugDescription: "The response date wasn't found on JSONDecoder 'userInfo'")
            throw DecodingError.valueNotFound(Date.self, ctx)
        }
        let timeDate = try container.decode(Date.self, forKey: .lastUpdate, with: DateFormatter.time)
        
        guard let update = responseDate.mixComponents([.year, .month, .day], withDate: timeDate, [.hour, .minute, .second], calendar: UTC.calendar, timezone: UTC.timezone) else {
            throw DecodingError.dataCorruptedError(forKey: .lastUpdate, in: container, debugDescription: "The update time couldn't be inferred")
        }
        
        if update > responseDate {
            guard let newDate = UTC.calendar.date(byAdding: DateComponents(day: -1), to: update) else {
                throw DecodingError.dataCorruptedError(forKey: .lastUpdate, in: container, debugDescription: "Error processing update time")
            }
            self.date = newDate
        } else {
            self.date = update
        }
        
        self.delay = try container.decode(TimeInterval.self, forKey: .delay)
        self.status = try container.decode(API.Market.Status.self, forKey: .status)
        self.price = try API.Market.Price(from: decoder)
        self.scalingFactor = try container.decode(Decimal64.self, forKey: .scalingFactor)
        self.decimalPlacesFactor = try container.decode(Int.self, forKey: .decimalPlacesFactor)
        self.extraSpreadForControlledRisk = try container.decode(Decimal64.self, forKey: .extraSpreadForControlledRisk)
        self.binaryOdds = try container.decodeIfPresent(Decimal64.self, forKey: .binaryOdds)
    }
    
    private enum _Keys: String, CodingKey {
        case lastUpdate = "updateTime"
        case delay = "delayTime"
        case status = "marketStatus"
        case scalingFactor
        case decimalPlacesFactor
        case extraSpreadForControlledRisk = "controlledRiskExtraSpread"
        case binaryOdds
        case bid, offer
        case high, low, netChange, percentageChange
    }
}

extension API.Market.Status: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "TRADEABLE": self = .tradeable
        case "CLOSED": self = .closed
        case "EDITS_ONLY": self = .editsOnly
        case "ON_AUCTION": self = .onAuction
        case "ON_AUCTION_NO_EDITS": self = .onAuctionNoEdits
        case "OFFLINE": self = .offline
        case "SUSPENDED": self = .suspended
        case let value: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid market status '\(value)'.")
        }
    }
}

extension API.Market.Price {
    public init?(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.bid = try container.decodeIfPresent(Decimal64.self, forKey: .bid)
        self.ask = try container.decodeIfPresent(Decimal64.self, forKey: .ask)
        let lowest = try container.decodeIfPresent(Decimal64.self, forKey: .lowest)
        let highest = try container.decodeIfPresent(Decimal64.self, forKey: .highest)
        guard case .some = self.bid, case .some = self.ask,
            case .some(let low) = lowest, case .some(let high) = highest else { return nil }
        (self.lowest, self.highest) = (low, high)
        self.change = (try container.decode(Decimal64.self, forKey: .netChange),
                       try container.decode(Decimal64.self, forKey: .percentageChange))
    }
    
    private enum _Keys: String, CodingKey {
        case bid, ask = "offer"
        case lowest = "low"
        case highest = "high"
        case netChange, percentageChange
    }
}

extension API.Market.Distance: Decodable {}

extension API.Market.Distance.Unit: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "POINTS": self = .points
        case "PERCENTAGE": self = .percentage
        case let value: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid distance unit '\(value)'.")
        }
    }
}
