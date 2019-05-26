import ReactiveSwift
import Foundation

extension API {
    /// Returns the details of the given markets.
    /// - parameter epics: The market epics to target onto. It cannot be empty.
    public func markets(epics: [String]) -> SignalProducer<[API.Response.Market],API.Error> {
        return self.makeRequest(.get, "markets", version: 2, credentials: true, queries: {
                let filteredEpics = epics.filter { !$0.isEmpty }
                let errorBlurb = "Search for market epics failed!"
                guard !filteredEpics.isEmpty else { throw API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) There needs to be at least one epic defined.") }
                guard filteredEpics.count <= 50 else { throw API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) You cannot pass more than 50 epics.") }
            
                return [URLQueryItem(name: "filter", value: "ALL"),
                        URLQueryItem(name: "epics", value: filteredEpics.joined(separator: ",")) ]
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (list: API.Response.MarketList) in list.marketDetails }
    }
    
    /// Returns the details of a given market.
    public func market(epic: String) -> SignalProducer<API.Response.Market,API.Error> {
        return self.makeRequest(.get, "markets/\(epic)", version: 3, credentials: true, queries: { () -> [URLQueryItem] in
                guard !epic.isEmpty else { throw API.Error.invalidRequest(underlyingError: nil, message: "Market retrieval failed! The epic cannot be empty.") }
                return []
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
    }
}

// MARK: -

extension API.Response {
    /// List of targeted markets.
    fileprivate struct MarketList: Decodable {
        /// Wrapper key for the market list use by these endpoints.
        let marketDetails: [Market]
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
    }
    
    /// Market details.
    public struct Market: Decodable {
        /// Market's dealing rules.
        public let dealingRules: Rules
        /// Instrument details.
        public let instrument: Instrument
        /// Market snapshot data.
        public let snapshot: Snapshot
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
    }
}

extension API.Response.Market {
    /// Instrument details.
    public struct Instrument: Decodable {
        /// Instrument type.
        public let type: API.Instrument.Kind
        /// Instrument identifier.
        public let epic: String
        /// Market expiration date details.
        public let expiration: Expiration
        /// Instrument name.
        public let name: String
        /// Currencies.
        public let currencies: [Currency]
        /// Contract size. In the case of CFDs, this is the number of contracts you wish to trade or of open positions. For spread bets this is the amount of profit or loss per point movement in the market
        public let contractSize: Double
        /// Lot size.
        public let lotSize: Double
        /// Unit used to qualify the size of a trade.
        public let unit: Unit
        /// Meaning and value of the Price Interest Point (a.k.a. PIP).
        public let pip: Pip
        /// Deposit bands.
        public let margin: Margin
        /// Slippage factor details for the given market.
        public let slippageFactor: SlippageFactor
        /// Market open and closes times.
        public let openingTime: [HourRange]?
        /// Market rollover details.
        public let rollover: Rollover?
        /// Properties of sprint markets.
        public let sprintMarket: SprintMarket?
        /// Boolean indicating whether "force open" is allowed.
        public let isForceOpenAllowed: Bool
        /// Boolean indicating whether stops and limits are allowed.
        public let isStopLimitAllowed: Bool
        /// Are controlled risk trades allowed.
        public let isControlledRiskAllowed: Bool
        /// The limited risk premium.
        public let limitedRiskPremium: API.Market.Distance
        /// Boolean indicating whether prices are available through streaming communications.
        public let isAvailableByStreaming: Bool
        /// Country.
        public let country: String?
        /// Market identifier.
        public let marketId: String
        /// Retuers news code.
        public let newsCode: String
        /// Chart code.
        public let chartCode: String
        /// List of special information notices.
        public let details: [String]?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.type = try container.decode(API.Instrument.Kind.self, forKey: .type)
            self.epic = try container.decode(String.self, forKey: .epic)
            self.expiration = try Expiration(from: decoder)
            self.name = try container.decode(String.self, forKey: .name)
            self.currencies = try container.decodeIfPresent([Currency].self, forKey: .currencies) ?? []
            let contractString = try container.decode(String.self, forKey: .contractSize)
            self.contractSize = try Double(contractString) ?! DecodingError.dataCorruptedError(forKey: CodingKeys.contractSize, in: container, debugDescription: "The contract size \"\(contractString)\" couldn't be parsed into a number.")
            self.lotSize = try container.decode(Double.self, forKey: .lotSize)
            self.unit = try container.decode(Unit.self, forKey: .unit)
            self.pip = try Pip(from: decoder)
            self.margin = try Margin(from: decoder)
            self.slippageFactor = try container.decode(SlippageFactor.self, forKey: .slippageFactor)
            self.rollover = try container.decodeIfPresent(Rollover.self, forKey: .rollover)
            self.sprintMarket = try SprintMarket(from: decoder)
            self.isForceOpenAllowed = try container.decode(Bool.self, forKey: .isForceOpenAllowed)
            self.isStopLimitAllowed = try container.decode(Bool.self, forKey: .isStopLimitAllowed)
            self.isControlledRiskAllowed = try container.decode(Bool.self, forKey: .isControlledRiskAllowed)
            self.limitedRiskPremium = try container.decode(API.Market.Distance.self, forKey: .limitedRiskPremium)
            self.isAvailableByStreaming = try container.decode(Bool.self, forKey: .isAvailableByStreaming)
            self.country = try container.decodeIfPresent(String.self, forKey: .country)
            self.marketId = try container.decode(String.self, forKey: .marketId)
            self.newsCode = try container.decode(String.self, forKey: .newsCode)
            self.chartCode = try container.decode(String.self, forKey: .chartCode)
            let details = try container.decodeIfPresent([String].self, forKey: .details)
            self.details = details.flatMap { (!$0.isEmpty) ? $0 : nil }
            
            if let wrapper = try container.decodeIfPresent([String:[HourRange]].self, forKey: .openingTime) {
                guard let times = wrapper[CodingKeys.openingMarketTimes.rawValue] else {
                    let debugLine = "Openning times wrapper key \"\(CodingKeys.openingMarketTimes.rawValue)\" was not found."
                    throw DecodingError.dataCorruptedError(forKey: .openingTime, in: container, debugDescription: debugLine)
                }
                self.openingTime = times
            } else {
                self.openingTime = nil
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case chartCode
            case contractSize
            case country
            case currencies
            case epic
            case isForceOpenAllowed = "forceOpenAllowed"
            case isControlledRiskAllowed = "controlledRiskAllowed"
            case limitedRiskPremium
            case lotSize
            case marketId
            case name
            case newsCode
            case openingTime = "openingHours"
            case openingMarketTimes = "marketTimes"
            case rollover = "rolloverDetails"
            case slippageFactor
            case details = "specialInfo"
            case isStopLimitAllowed = "stopsLimitsAllowed"
            case isAvailableByStreaming = "streamingPricesAvailable"
            case type
            case unit
        }
    }
    
    /// Dealing rule preferences.
    public struct Rules: Decodable {
        /// Client's market order trading preference.
        public let marketOrder: Order
        /// Maximum stop or limit distance.
        public let maxStop: API.Market.Distance
        /// Minimum controller risk stop distance.
        public let minControlledRiskStop: API.Market.Distance
        /// Minimum deal size.
        public let minDealSize: API.Market.Distance
        /// Minimum normal stop or limit distance.
        public let minNormalStop: API.Market.Distance
        /// Minimum step distance.
        public let minStepDistance: API.Market.Distance
        /// Trailing stops trading preference.
        public let trailingStops: TrailingStops
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
        
        private enum CodingKeys: String, CodingKey {
            case marketOrder = "marketOrderPreference"
            case maxStop = "maxStopOrLimitDistance"
            case minControlledRiskStop = "minControlledRiskStopDistance"
            case minDealSize
            case minNormalStop = "minNormalStopOrLimitDistance"
            case minStepDistance
            case trailingStops = "trailingStopsPreference"
        }
    }
    
    /// Market snapshot data.
    public struct Snapshot: Decodable {
        /// The current status of a given market.
        public let status: API.Market.Status
        /// Multiplying factor to determine actual pip value for the levels used by the instrument.
        public let scalingFactor: Double
        /// Number of decimal positions for market levels.
        public let decimalPlacesFactor: Int
        /// The number of points to add on each side of the market as an additional spread when placing a guaranteed stop trade.
        public let extraSpreadForControlledRisk: Double
        /// Binary odds.
        public let binaryOdds: Double?
        /// Time of the last price update.
        public let lastUpdate: Date
        /// Offer (buy) and bid (sell) price.
        public let price: (offer: Double, bid: Double, delay: Double)
        /// Highest and lowest price of the day.
        public let range: (low: Double, high: Double)
        /// Price change net and percentage change on that day.
        public let change: (net: Double, percentage: Double)
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.status = try container.decode(API.Market.Status.self, forKey: .status)
            self.scalingFactor = try container.decode(Double.self, forKey: .scalingFactor)
            self.decimalPlacesFactor = try container.decode(Int.self, forKey: .decimalPlacesFactor)
            self.extraSpreadForControlledRisk = try container.decode(Double.self, forKey: .extraSpreadForControlledRisk)
            self.binaryOdds = try container.decodeIfPresent(Double.self, forKey: .binaryOdds)
            self.lastUpdate = try container.decode(Date.self, forKey: .lastUpdate, with: API.DateFormatter.time)
            let offer = try container.decode(Double.self, forKey: .offer)
            let bid = try container.decode(Double.self, forKey: .bid)
            let delay = try container.decode(Double.self, forKey: .delay)
            self.price = (offer, bid, delay)
            let low = try container.decode(Double.self, forKey: .low)
            let high = try container.decode(Double.self, forKey: .high)
            self.range = (low, high)
            let netChange = try container.decode(Double.self, forKey: .netChange)
            let percentageChange = try container.decode(Double.self, forKey: .percentageChange)
            self.change = (netChange, percentageChange)
        }
        
        private enum CodingKeys: String, CodingKey {
            case status = "marketStatus"
            case scalingFactor, decimalPlacesFactor
            case extraSpreadForControlledRisk = "controlledRiskExtraSpread"
            case binaryOdds
            case lastUpdate = "updateTime"
            case bid, offer, delay = "delayTime"
            case high, low, netChange, percentageChange
        }
    }
}

extension API.Response.Market.Instrument {
    /// An instrument currency.
    public struct Currency: Decodable {
        /// Symbol for display purposes.
        public let symbol: String
        /// Code to be used when placing orders.
        public let code: String
        /// Base exchange rate.
        public let baseExchangeRate: Double
        /// Exchange rate.
        public let exchangeRate: Double
        /// Is it the default currency?
        public let isDefault: Bool
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
    }
    
    /// Expiration date details.
    public struct Expiration: Decodable {
        /// Expiration date. The date (and sometimes time) at which a spreadbet or CFD will automatically close against some predefined market value should the bet remain open beyond its last dealing time. Some CFDs do not expire, and have an expiry of '-'. eg DEC-14, or DFB for daily funded bets.
        public let expiry: API.Expiry
        /// Settlement information.
        public let settlement: String?
        /// The last dealing dealing date.
        public let lastDealingDate: Date?
        
        /// Modification of the original `Decodable` initializer to support IG's weird logic.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.expiry = try container.decodeIfPresent(API.Expiry.self, forKey: .expirationDate) ?? .none
            guard container.contains(.expirationDetails), !(try container.decodeNil(forKey: .expirationDetails)) else {
                self.settlement = nil
                self.lastDealingDate = nil; return
            }
            
            let nestedContainer = try container.nestedContainer(keyedBy: CodingKeys.NestedKeys.self, forKey: .expirationDetails)
            self.settlement = try nestedContainer.decodeIfPresent(String.self, forKey: .settlement)
            self.lastDealingDate = try nestedContainer.decodeIfPresent(Date.self, forKey: .lastDealingDate, with: API.DateFormatter.iso8601NoTimezoneSeconds)
        }
        
        private enum CodingKeys: String, CodingKey {
            case expirationDate = "expiry"
            case expirationDetails = "expiryDetails"
            
            enum NestedKeys: String, CodingKey {
                case settlement = "settlementInfo"
                case lastDealingDate = "lastDealingDate"
            }
        }
    }
    
    /// Margin requirements and deposit bands.
    public struct Margin: Decodable {
        /// The dimension for a dealing rule value.
        public let unit: API.Market.Distance.Unit
        /// Margin requirement factor.
        public let factor: Double
        /// Deposit bands.
        public let depositBands: [Band]
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.unit = try container.decode(API.Market.Distance.Unit.self, forKey: .marginUnit)
            self.factor = try container.decode(Double.self, forKey: .marginFactor)
            self.depositBands = try container.decode([Band].self, forKey: .marginBands)
        }
        
        private enum CodingKeys: String, CodingKey {
            case marginUnit = "marginFactorUnit"
            case marginFactor
            case marginBands = "marginDepositBands"
        }
        
        public struct Band: Decodable {
            /// The currency for this currency band factor calculation.
            public let currency: String
            /// Margin percentage.
            public let margin: Double
            /// Band maximum.
            public let max: Double?
            /// Band minimum.
            public let min: Double
            
            /// Do not call! The only way to initialize is through `Decodable`.
            private init?() { fatalError("Unaccessible initializer") }
        }
    }
    
    /// Market Pip (Price Interest Point).
    public struct Pip: Decodable {
        /// What one pip actually signifies.
        public let meaning: String
        /// What is the value of one pip.
        public let value: String
        
        private enum CodingKeys: String, CodingKey {
            case meaning = "onePipMeans"
            case value = "valueOfOnePip"
        }
    }
    
    /// Market open and close times.
    public struct HourRange: Decodable {
        public let open: String
        public let close: String
        
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
        
        private enum CodingKeys: String, CodingKey {
            case open = "openTime"
            case close = "closeTime"
        }
    }
    
    /// Instrument rollover details {
    public struct Rollover: Decodable {
        public let lastDate: Date
        public let info: String
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.lastDate = try container.decode(Date.self, forKey: .lastDate, with: API.DateFormatter.iso8601NoTimezoneSeconds)
            self.info = try container.decode(String.self, forKey: .info)
        }
        
        private enum CodingKeys: String, CodingKey {
            case lastDate = "lastRolloverTime"
            case info = "rolloverInfo"
        }
    }
    
    /// Distance/Size preference.
    public struct SlippageFactor: Decodable {
        public let unit: String
        public let value: Double
    }
    
    /// Sprint market property.
    public struct SprintMarket {
        /// The minimum value to be specified as the expiration of a sprint markets trade.
        public let minExpirationDate: Date
        /// The maximum value to be specified as the expiration of a sprint markets trade.
        public let maxExpirationDate: Date
        
        /// Modification of the original `Decodable` initializer to support IG's weird logic.
        public init?(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let hasMin = try container.decodeNil(forKey: .sprintMin)
            let hasMax = try container.decodeNil(forKey: .sprintMax)
            guard hasMin == hasMax else { throw DecodingError.dataCorruptedError(forKey: .sprintMax, in: container, debugDescription: "Sprint market has an invalid min/max range.") }
            guard hasMin == false else { return nil }
            
            self.minExpirationDate = try container.decode(Date.self, forKey: .sprintMin, with: API.DateFormatter.monthYear)
            self.maxExpirationDate = try container.decode(Date.self, forKey: .sprintMax, with: API.DateFormatter.monthYear)
        }
        
        private enum CodingKeys: String, CodingKey {
            case sprintMin = "sprintMarketsMinimumExpiryTime"
            case sprintMax = "sprintMarketsMaximumExpiryTime"
        }
    }
    
    /// Unit used to qualify the size of a trade.
    public enum Unit: String, Decodable {
        case amount = "AMOUNT"
        case contracts = "CONTRACTS"
        case shares = "SHARES"
    }
}

extension API.Response.Market.Rules {
    /// Market order trading preference.
    public enum Order: Decodable {
        /// Market orders are not allowed for the current site and/or instrument.
        case unavailable
        /// Market orders are allowed for the account type and instrument and the user has enabled market orders in their preferences.
        /// The user has also decided whether that should be the default.
        case available(default: Bool)
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let preference = try container.decode(String.self)
            
            switch preference {
            case "NOT_AVAILABLE": self = .unavailable
            case "AVAILABLE_DEFAULT_ON": self = .available(default: true)
            case "AVAILABLE_DEFAULT_OFF": self = .available(default: false)
            default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Market order preference \"\(preference)\" not recognized.")
            }
        }
    }
    
    /// Trailing stops trading preference for the specified market.
    public enum TrailingStops: String, Decodable {
        /// Trading stops are allowed for the current market.
        case available = "AVAILABLE"
        /// Trailing stops are not allowed for the current market.
        case unavailable = "NOT_AVAILABLE"
    }
}
