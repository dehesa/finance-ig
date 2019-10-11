import Combine
import Foundation

extension IG.API.Request {
    /// List of endpoints related to API markets.
    public struct Markets {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        internal unowned let api: IG.API
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoint.
        init(api: IG.API) {
            self.api = api
        }
    }
}

extension IG.API.Request.Markets {
    
    // MARK: GET /markets/{epic}
    
    /// Returns the details of a given market.
    /// - parameter epic: The market epic to target onto. It cannot be empty.
    /// - returns: Information about the targeted market.
    public func get(epic: IG.Market.Epic) -> IG.API.DiscretePublisher<IG.API.Market> {
        self.api.publisher { (api) -> DateFormatter in
                guard let timezone = api.channel.credentials?.timezone else {
                    throw IG.API.Error.invalidRequest(IG.API.Error.Message.noCredentials, suggestion: IG.API.Error.Suggestion.logIn)
                }
                return IG.API.Formatter.iso8601NoSeconds.deepCopy(timeZone: timezone)
            }.makeRequest(.get, "markets/\(epic.rawValue)", version: 3, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(values: true, date: true)).mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
        
    }
    
    // MARK: GET /markets
    
    /// Returns the details of the given markets.
    /// - parameter epics: The market epics to target onto. It cannot be empty or greater than 50.
    /// - returns: Extended information of all the requested markets.
    public func get(epics: Set<IG.Market.Epic>) -> IG.API.DiscretePublisher<[IG.API.Market]> {
        return Self.get(api: self.api, epics: epics)
    }
    
    /// Returns the details of the given markets.
    ///
    /// This endpoint circumvents `get(epics:)` limitation of quering for 50 markets and publish the results as several values.
    /// - parameter epics: The market epics to target onto. It cannot be empty.
    /// - returns: Extended information of all the requested markets.
    public func getContinuously(epics: Set<IG.Market.Epic>) -> IG.API.ContinuousPublisher<[IG.API.Market]> {
        let maxEpicsPerChunk = 50
        guard epics.count > maxEpicsPerChunk else { return Self.get(api: api, epics: epics) }
        
        return self.api.publisher({ (_) in epics.chunked(into: maxEpicsPerChunk) })
            .flatMap { (api, chunks) -> PassthroughSubject<[IG.API.Market],IG.API.Error> in
                let subject = PassthroughSubject<[IG.API.Market],IG.API.Error>()
                
                /// Closure retrieving the chunk at the given index through the given API instance.
                var fetchChunk: ((_ api: IG.API, _ index: Int)->AnyCancellable?)! = nil
                /// `Cancellable` to stop fetching chunks.
                var cancellable: AnyCancellable? = nil
                
                fetchChunk = { (chunkAPI: IG.API, chunkIndex) in
                    Self.get(api: chunkAPI, epics: chunks[chunkIndex])
                        .sink(receiveCompletion: { [weak weakAPI = chunkAPI] in
                            if case .failure(let error) = $0 {
                                subject.send(completion: .failure(error))
                                cancellable = nil
                                return
                            }
                            
                            let nextChunk = chunkIndex + 1
                            guard nextChunk < chunks.count else {
                                subject.send(completion: .finished)
                                cancellable = nil
                                return
                            }
                            
                            guard let api = weakAPI else {
                                subject.send(completion: .failure(.sessionExpired()))
                                cancellable = nil
                                return
                            }
                            
                            cancellable = fetchChunk(api, nextChunk)
                        }, receiveValue: { subject.send($0) })
                }
                
                defer { cancellable = fetchChunk(api, 0) }
                return subject
            }.eraseToAnyPublisher()
    }
    
    /// Returns the details of the given markets.
    /// - parameter epics: The market epics to target onto. It cannot be empty or greater than 50.
    /// - returns: Extended information of all the requested markets.
    private static func get(api: API, epics: Set<IG.Market.Epic>) -> IG.API.DiscretePublisher<[IG.API.Market]> {
        api.publisher { (api) -> DateFormatter in
                let epicRange = 1...50
                guard epicRange.contains(epics.count) else {
                    let message = "Only between 1 to 50 markets can be queried at the same time"
                    let suggestion = (epics.isEmpty) ? "Request at least one market" : "The request tried to query \(epics.count) markets. Restrict the query to \(epicRange.upperBound) (included)"
                    throw IG.API.Error.invalidRequest(.init(message), suggestion: .init(suggestion))
                }
                
                guard let timezone = api.channel.credentials?.timezone else {
                    throw IG.API.Error.invalidRequest(IG.API.Error.Message.noCredentials, suggestion: IG.API.Error.Suggestion.logIn)
                }
                return IG.API.Formatter.iso8601NoSeconds.deepCopy(timeZone: timezone)
            }.makeRequest(.get, "markets", version: 2, credentials: true, queries: { (_) in
                [.init(name: "filter", value: "ALL"),
                 .init(name: "epics", value: epics.map { $0.rawValue }.joined(separator: ",")) ]
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(values: true, date: true)) { (l: Self.WrapperList, _) in l.marketDetails }
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension IG.API.Request.Markets {
    private struct WrapperList: Decodable {
        let marketDetails: [IG.API.Market]
    }
}

extension IG.API {
    /// A financial market, which may refer to an underlying financial market, or the market being offered in terms of an IG instrument.
    ///
    /// IG instruments are organised in the form a navigable market hierarchy
    public struct Market: Decodable {
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
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.instrument = try container.decode(Self.Instrument.self, forKey: .instrument)
            self.rules = try container.decode(Self.Rules.self, forKey: .rules)
            self.snapshot = try container.decode(Self.Snapshot.self, forKey: .snapshot)
            
            let instrumentContainer = try container.nestedContainer(keyedBy: Self.CodingKeys.InstrumentKeys.self, forKey: .instrument)
            self.identifier = try (instrumentContainer).decodeIfPresent(String.self, forKey: .identifier)
        }

        private enum CodingKeys: String, CodingKey {
            case instrument
            case rules = "dealingRules"
            case snapshot
            
            enum InstrumentKeys: String, CodingKey {
                case identifier = "marketId"
            }
        }
    }
}

extension IG.API.Market {
    /// Instrument details.
    public struct Instrument: Decodable {
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
        public let lotSize: Decimal
        /// Contract size.
        ///
        /// - For CFDs, this is the number of contracts you wish to trade or of open positions.
        /// - For spread bets this is the amount of profit or loss per point movement in the market
        public let contractSize: Decimal?
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
        public let limitedRiskPremium: IG.API.Market.Distance
        /// Chart code.
        public let chartCode: String?
        /// Retuers news code.
        public let newsCode: String
        /// List of special information notices.
        public let details: [String]?
        /// Properties of sprint markets.
        public let sprintMarket: Self.SprintMarket?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.epic = try container.decode(IG.Market.Epic.self, forKey: .epic)
            self.name = try container.decode(String.self, forKey: .name)
            self.type = try container.decode(IG.API.Market.Instrument.Kind.self, forKey: .type)
            self.unit = try container.decode(Self.Unit.self, forKey: .unit)
            self.expiration = try .init(from: decoder)
            self.country = try container.decodeIfPresent(String.self, forKey: .country)
            self.currencies = try container.decodeIfPresent(Array<Self.Currency>.self, forKey: .currencies) ?? []
            
            if let wrapper = try container.decodeIfPresent([String:Array<Self.HourRange>].self, forKey: .openingTime) {
                self.openingTime = try wrapper[Self.CodingKeys.openingMarketTimes.rawValue]
                    ?! DecodingError.dataCorruptedError(forKey: .openingTime, in: container, debugDescription: "Openning times wrapper key \"\(Self.CodingKeys.openingMarketTimes.rawValue)\" was not found")
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
            
            self.lotSize = try container.decode(Decimal.self, forKey: .lotSize)
            if let contractString = try container.decodeIfPresent(String.self, forKey: .contractSize) {
                self.contractSize = try Decimal(string: contractString)
                    ?! DecodingError.dataCorruptedError(forKey: .contractSize, in: container, debugDescription: "The contract size \"\(contractString)\" couldn't be parsed into a number")
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
            self.limitedRiskPremium = try container.decode(IG.API.Market.Distance.self, forKey: .limitedRiskPremium)
            self.chartCode = try container.decodeIfPresent(String.self, forKey: .chartCode)
            self.newsCode = try container.decode(String.self, forKey: .newsCode)
            let details = try container.decodeIfPresent([String].self, forKey: .details)
            self.sprintMarket = try SprintMarket(from: decoder)
            self.details = details.flatMap { (!$0.isEmpty) ? $0 : nil }
        }
        
        private enum CodingKeys: String, CodingKey {
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
}

extension IG.API.Market.Instrument {
    /// Instrument related entities.
    public enum Kind: RawRepresentable, Decodable {
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
        
        public enum Bungee: String {
            case capped, commodities, currencies, indices
        }
        
        public enum Options: String {
            case commodities, currencies, indices, rates, shares
        }
        
        public init?(rawValue: String) {
            typealias V = Self.Value
            switch rawValue {
            case V.binary:       self = .binary
            case V.commodities:  self = .commodities
            case V.currencies:   self = .currencies
            case V.indices:      self = .indices
            case V.optionsCommodities: self = .options(.commodities)
            case V.optionCurrencies:   self = .options(.currencies)
            case V.optionIndices:      self = .options(.indices)
            case V.optionRates:        self = .options(.rates)
            case V.optionShares:       self = .options(.shares)
            case V.rates:        self = .rates
            case V.sectors:      self = .sectors
            case V.shares:       self = .shares
            case V.sprintMarket: self = .sprintMarket
            case V.testMarket:   self = .testMarket
            case V.bungeeCapped:       self = .bungee(.capped)
            case V.bungeeCommodities:  self = .bungee(.commodities)
            case V.bungeeCurrencies:   self = .bungee(.currencies)
            case V.bungeeIndices:      self = .bungee(.indices)
            case V.unknown:      self = .unknown
            default: return nil
            }
        }
        
        public var rawValue: String {
            typealias V = Self.Value
            switch self {
            case .binary:       return V.binary
            case .commodities:  return V.commodities
            case .currencies:   return V.currencies
            case .indices:      return V.indices
            case .options(let type):
                switch type {
                case .commodities:  return V.optionsCommodities
                case .currencies:   return V.optionCurrencies
                case .indices:      return V.optionIndices
                case .rates:        return V.optionRates
                case .shares:       return V.optionShares
                }
            case .rates:        return V.rates
            case .sectors:      return V.sectors
            case .shares:       return V.shares
            case .sprintMarket: return V.sprintMarket
            case .testMarket:   return V.testMarket
            case .bungee(let type):
                switch type {
                case .capped:       return V.bungeeCapped
                case .commodities:  return V.bungeeCommodities
                case .currencies:   return V.bungeeCurrencies
                case .indices:      return V.bungeeIndices
                }
            case .unknown:      return V.unknown
            }
        }
        
        private enum Value {
            static let binary = "BINARY"
            static let commodities = "COMMODITIES"
            static let currencies = "CURRENCIES"
            static let indices = "INDICES"
            static let optionsCommodities = "OPT_COMMODITIES"
            static let optionCurrencies = "OPT_CURRENCIES"
            static let optionIndices = "OPT_INDICES"
            static let optionRates = "OPT_RATES"
            static let optionShares = "OPT_SHARES"
            static let rates = "RATES"
            static let sectors = "SECTORS"
            static let shares = "SHARES"
            static let sprintMarket = "SPRINT_MARKET"
            static let testMarket = "TEST_MARKET"
            static let bungeeCapped = "BUNGEE_CAPPED"
            static let bungeeCommodities = "BUNGEE_COMMODITIES"
            static let bungeeCurrencies = "BUNGEE_CURRENCIES"
            static let bungeeIndices = "BUNGEE_INDICES"
            static let unknown = "UNKNOWN"
        }
    }
    
    /// Expiration date details.
    public struct Expiration: Decodable {
        /// Expiration date. The date (and sometimes time) at which a spreadbet or CFD will automatically close against some predefined market value should the bet remain open beyond its last dealing time. Some CFDs do not expire, and have an expiry of '-'. eg DEC-14, or DFB for daily funded bets.
        public let expiry: IG.Market.Expiry
        /// The last dealing date.
        public let lastDealingDate: Date?
        /// Settlement information.
        public let settlementInfo: String?

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)

            self.expiry = try container.decodeIfPresent(IG.Market.Expiry.self, forKey: .expirationDate) ?? .none
            guard container.contains(.expirationDetails), !(try container.decodeNil(forKey: .expirationDetails)) else {
                self.settlementInfo = nil
                self.lastDealingDate = nil
                return
            }

            let nestedContainer = try container.nestedContainer(keyedBy: Self.CodingKeys.NestedKeys.self, forKey: .expirationDetails)
            self.settlementInfo = try nestedContainer.decodeIfPresent(String.self, forKey: .settlementInfo)
            
            let formatter = try decoder.userInfo[IG.API.JSON.DecoderKey.computedValues] as? DateFormatter
                ?! DecodingError.dataCorruptedError(forKey: .lastDealingDate, in: nestedContainer, debugDescription: "The date formatter supposed to be passed as user info couldn't be found")
            self.lastDealingDate = try nestedContainer.decodeIfPresent(Date.self, forKey: .lastDealingDate, with: formatter)
        }

        private enum CodingKeys: String, CodingKey {
            case expirationDate = "expiry"
            case expirationDetails = "expiryDetails"

            enum NestedKeys: String, CodingKey {
                case settlementInfo
                case lastDealingDate = "lastDealingDate"
            }
        }
    }
    
    /// An instrument currency.
    public struct Currency: Decodable {
        /// Symbol for display purposes.
        public let symbol: String
        /// Code to be used when placing orders.
        public let code: IG.Currency.Code
        /// Base exchange rate.
        public let baseExchangeRate: Decimal
        /// Exchange rate.
        public let exchangeRate: Decimal
        /// Is it the default currency?
        public let isDefault: Bool
        /// Do not call! The only way to initialize is through `Decodable`.
        private init?() { fatalError("Unaccessible initializer") }
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
    
    /// Unit used to qualify the size of a trade.
    public enum Unit: String, Decodable {
        case amount = "AMOUNT"
        case contracts = "CONTRACTS"
        case shares = "SHARES"
    }
    
    /// Market Pip (Price Interest Point).
    public struct Pip: Decodable {
        /// What one pip actually signifies.
        public let meaning: String
        /// What is the value of one pip.
        public let value: String
    }

    /// Margin requirements and deposit bands.
    public struct Margin: Decodable {
        /// Margin requirement factor.
        public let factor: Decimal
        /// The dimension for the margin factor.
        public let unit: IG.API.Market.Distance.Unit
        /// Deposit bands.
        public let depositBands: [Self.Band]

        private enum CodingKeys: String, CodingKey {
            case factor = "marginFactor"
            case unit = "marginFactorUnit"
            case depositBands = "marginDepositBands"
        }

        public struct Band: Decodable {
            /// The currency for this currency band factor calculation.
            public let currencyCode: IG.Currency.Code
            /// Margin percentage.
            public let margin: Decimal
            /// Band minimum.
            public let minimum: Decimal
            /// Band maximum.
            public let maximum: Decimal?
            /// Do not call! The only way to initialize is through `Decodable`.
            private init?() { fatalError("Unaccessible initializer") }
            
            private enum CodingKeys: String, CodingKey {
                case currencyCode = "currency"
                case margin
                case minimum = "min"
                case maximum = "max"
            }
        }
    }
    
    /// Distance/Size preference.
    public struct SlippageFactor: Decodable {
        public let value: Decimal
        public let unit: Unit
        
        public enum Unit: String, Decodable {
            case percentage = "pct"
        }
    }

    /// Instrument rollover details.
    public struct Rollover: Decodable {
        public let lastDate: Date
        public let info: String

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            guard let formatter = decoder.userInfo[IG.API.JSON.DecoderKey.computedValues] as? DateFormatter else {
                throw DecodingError.dataCorruptedError(forKey: .lastDate, in: container, debugDescription: "The date formatter supposed to be passed as user info couldn't be found")
            }
            
            self.lastDate = try container.decode(Date.self, forKey: .lastDate, with: formatter)
            self.info = try container.decode(String.self, forKey: .info)
        }

        private enum CodingKeys: String, CodingKey {
            case lastDate = "lastRolloverTime"
            case info = "rolloverInfo"
        }
    }

    /// Sprint market property.
    public struct SprintMarket {
        /// The minimum value to be specified as the expiration of a sprint markets trade.
        public let minExpirationDate: Date
        /// The maximum value to be specified as the expiration of a sprint markets trade.
        public let maxExpirationDate: Date

        public init?(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            switch (try container.decodeNil(forKey: .sprintMin), try container.decodeNil(forKey: .sprintMax)) {
            case (false, false): break
            case (true, true): return nil
            default: throw DecodingError.dataCorruptedError(forKey: .sprintMax, in: container, debugDescription: "Sprint market has an invalid min/max range")
            }

            self.minExpirationDate = try container.decode(Date.self, forKey: .sprintMin, with: IG.API.Formatter.dateDenormalBroad)
            self.maxExpirationDate = try container.decode(Date.self, forKey: .sprintMax, with: IG.API.Formatter.dateDenormalBroad)
        }

        private enum CodingKeys: String, CodingKey {
            case sprintMin = "sprintMarketsMinimumExpiryTime"
            case sprintMax = "sprintMarketsMaximumExpiryTime"
        }
    }
}

extension IG.API.Market {
    /// Dealing rule preferences.
    public struct Rules: Decodable {
        /// Client's market order trading preference.
        ///
        /// An order that you use to specify the direction and size of a bet, but not the price.
        /// This ensures we will fill your order as quickly as possible, even if the price indicated on the deal ticket is not available for your requested order size
        public let marketOrder: Self.Order
        /// Minimum deal size.
        public let minimumDealSize: IG.API.Market.Distance
        /// Rules for setting postions' limits.
        public let limit: Self.Limit
        /// Rules for setting positions' stops.
        public let stop: Self.Stop
        
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.marketOrder = try container.decode(Self.Order.self, forKey: .marketOrder)
            self.minimumDealSize = try container.decode(IG.API.Market.Distance.self, forKey: .minimumDealSize)
            self.limit = try .init(from: decoder)
            self.stop = try .init(from: decoder)
        }
        
        private enum CodingKeys: String, CodingKey {
            case marketOrder = "marketOrderPreference"
            case minimumDealSize = "minDealSize"
        }
        
        /// Market order trading preference.
        public enum Order: RawRepresentable, Decodable {
            /// Market orders are not allowed for the current site and/or instrument.
            case unavailable
            /// Market orders are allowed for the account type and instrument and the user has enabled market orders in their preferences.
            /// The user has also decided whether that should be the default.
            case available(isDefault: Bool)
            
            public init?(rawValue: String) {
                switch rawValue {
                case Self.Value.unavailable:  self = .unavailable
                case Self.Value.availableOff: self = .available(isDefault: false)
                case Self.Value.availableOn:  self = .available(isDefault: true)
                default: return nil
                }
            }
            
            public var rawValue: String {
                switch self {
                case .unavailable: return Self.Value.unavailable
                case .available(isDefault: false): return Self.Value.availableOff
                case .available(isDefault: true): return Self.Value.availableOn
                }
            }
            
            private enum Value {
                static let unavailable = "NOT_AVAILABLE"
                static let availableOn = "AVAILABLE_DEFAULT_ON"
                static let availableOff = "AVAILABLE_DEFAULT_OFF"
            }
        }
        
        /// Settings for positions' limits.
        public struct Limit: Decodable {
            /// Minimum normal limit distance.
            public let mininumDistance: IG.API.Market.Distance
            /// Maximum limit distance.
            public let maximumDistance: IG.API.Market.Distance
            
            private enum CodingKeys: String, CodingKey {
                case mininumDistance = "minNormalStopOrLimitDistance"
                case maximumDistance = "maxStopOrLimitDistance"
            }
        }
        
        /// Settings for positions' stops.
        public struct Stop: Decodable {
            /// Minimum normal stop distance.
            public let mininumDistance: IG.API.Market.Distance
            /// Minimum controller risk stop distance.
            public let minimumLimitedRiskDistance: IG.API.Market.Distance
            /// Maximum stop distance.
            public let maximumDistance: IG.API.Market.Distance
            /// Trailing stops' settings.
            public let trailing: Self.Trailing
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: Self.CodingKeys.self)
                self.mininumDistance = try container.decode(IG.API.Market.Distance.self, forKey: .mininumDistance)
                self.minimumLimitedRiskDistance = try container.decode(IG.API.Market.Distance.self, forKey: .limitedRisk)
                self.maximumDistance = try container.decode(IG.API.Market.Distance.self, forKey: .maximumDistance)
                self.trailing = try .init(from: decoder)
            }
            
            private enum CodingKeys: String, CodingKey {
                case mininumDistance = "minNormalStopOrLimitDistance"
                case limitedRisk = "minControlledRiskStopDistance"
                case maximumDistance = "maxStopOrLimitDistance"
            }
            
            /// Settings for positions' trailing stops.
            public struct Trailing: Decodable {
                /// Trailing stops trading preference.
                public let areAvailable: Bool
                /// Minimum step distance.
                public let minimumIncrement: IG.API.Market.Distance
                
                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: Self.CodingKeys.self)
                    self.minimumIncrement = try container.decode(IG.API.Market.Distance.self, forKey: .minimumIncrement)
                    let trailingStops = try container.decode(Self.Availability.self, forKey: .areTrailingStopsAvailable)
                    self.areAvailable = trailingStops == .available
                }
                
                private enum CodingKeys: String, CodingKey {
                    case minimumIncrement = "minStepDistance"
                    case areTrailingStopsAvailable = "trailingStopsPreference"
                }
                
                private enum Availability: String, Decodable {
                    case available = "AVAILABLE"
                    case unavailable = "NOT_AVAILABLE"
                }
            }
        }
    }
}

extension IG.API.Market {
    /// Market snapshot data.
    public struct Snapshot: Decodable {
        /// Time of the last price update.
        /// - attention: Although a full date is given, only the hours:minutes:seconds are meaningful.
        public let date: Date
        /// Pirce delay marked in minutes.
        public let delay: TimeInterval
        /// The current status of a given market
        public let status: IG.API.Market.Status
        /// The state of the market price at the time of the snapshot.
        public let price: IG.API.Market.Price?
        /// Multiplying factor to determine actual pip value for the levels used by the instrument.
        public let scalingFactor: Decimal
        /// Number of decimal positions for market levels.
        public let decimalPlacesFactor: Int
        /// The number of points to add on each side of the market as an additional spread when placing a guaranteed stop trade.
        public let extraSpreadForControlledRisk: Decimal
        /// Binary odds.
        public let binaryOdds: Decimal?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            guard let responseDate = decoder.userInfo[IG.API.JSON.DecoderKey.responseDate] as? Date else {
                let ctx = DecodingError.Context(codingPath: container.codingPath, debugDescription: #"The response date wasn't found on JSONDecoder "userInfo""#)
                throw DecodingError.valueNotFound(Date.self, ctx)
            }
            let timeDate = try container.decode(Date.self, forKey: .lastUpdate, with: IG.API.Formatter.time)
            
            guard let update = responseDate.mixComponents([.year, .month, .day], withDate: timeDate, [.hour, .minute, .second], calendar: IG.UTC.calendar, timezone: IG.UTC.timezone) else {
                throw DecodingError.dataCorruptedError(forKey: .lastUpdate, in: container, debugDescription: "The update time couldn't be inferred")
            }
            
            if update > responseDate {
                guard let newDate = IG.UTC.calendar.date(byAdding: DateComponents(day: -1), to: update) else {
                    throw DecodingError.dataCorruptedError(forKey: .lastUpdate, in: container, debugDescription: "Error processing update time")
                }
                self.date = newDate
            } else {
                self.date = update
            }
            
            self.delay = try container.decode(TimeInterval.self, forKey: .delay)
            self.status = try container.decode(IG.API.Market.Status.self, forKey: .status)
            self.price = try IG.API.Market.Price(from: decoder)
            self.scalingFactor = try container.decode(Decimal.self, forKey: .scalingFactor)
            self.decimalPlacesFactor = try container.decode(Int.self, forKey: .decimalPlacesFactor)
            self.extraSpreadForControlledRisk = try container.decode(Decimal.self, forKey: .extraSpreadForControlledRisk)
            self.binaryOdds = try container.decodeIfPresent(Decimal.self, forKey: .binaryOdds)
        }
        
        private enum CodingKeys: String, CodingKey {
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
}

extension IG.API.Market {
    /// Distance/Size preference.
    public struct Distance: Decodable {
        /// The distance value.
        public let value: Decimal
        /// The unit at which the `value` is measured against.
        public let unit: Unit
        
        public enum Unit: String, Decodable {
            case points = "POINTS"
            case percentage = "PERCENTAGE"
        }
    }
}

// MARK: - Functionality

extension IG.API.Market: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.API.printableDomain).\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("epic", self.instrument.epic)
        result.append("name", self.instrument.name)
        result.append("market ID", self.identifier)
        result.append("chart code", self.instrument.chartCode)
        result.append("news code", self.instrument.newsCode)
        
        let dayMonthYear = IG.API.Formatter.date
        let dateTime = IG.API.Formatter.timestamp.deepCopy(timeZone: .current)
        result.append("instrument", self.instrument) {
            $0.append("type", $1.type)
            $0.append("unit", $1.unit)
            
            let expiryValue: String
            switch $1.expiration.expiry {
            case .none: expiryValue = IG.DebugDescription.Symbol.nil
            case .dailyFunded: expiryValue = "Daily funded"
            case .forward(let date): expiryValue = dayMonthYear.string(from: date)
            }
            $0.append("expiry: \(expiryValue)", delimiter: false, $1.expiration) {
                if let date = $1.lastDealingDate {
                    $0.append("last dealing date", date, formatter: dateTime)
                }
                if let info = $1.settlementInfo {
                    $0.append("settlement information", info)
                }
            }
            
            $0.append("country", $1.country)
            $0.append("currencies", $1.currencies.map { "\($0.code) (base: \($0.baseExchangeRate), rate: \($0.exchangeRate))" })
            $0.append("opening hours", $1.openingTime?.map { "\($0.open) to \($0.close)" })
            $0.append("PIP", $1.pip.map { "\($0.meaning), value: \($0.value)" })
            $0.append("lot size", $1.lotSize)
            $0.append("contract size", $1.contractSize)
            $0.append("is force open allowed", $1.isForceOpenAllowed)
            $0.append("is stop limit allowed", $1.isStopLimitAllowed)
            $0.append("is guaranteed stop allowed", $1.isLimitedRiskAllowed)
            $0.append("is available by streaming", $1.isAvailableByStreaming)
            $0.append("margin", $1.margin) {
                $0.append("factor", "\(String(describing: $1.factor)) \($1.unit.rawValue)")
                $0.append("bands", $1.depositBands.map { "\($0.minimum)..<\($0.maximum.map { String(describing: $0) } ?? "max") \($0.currencyCode) -> \($0.margin)%" })
            }
            $0.append("slippage factor", "\($1.slippageFactor.value) \($1.slippageFactor.unit)")
            $0.append("rollover", $1.rollover) {
                $0.append("date", $1.lastDate, formatter: dayMonthYear)
                $0.append("info", $1.info)
            }
            $0.append("limited risk premium", "\($1.limitedRiskPremium.value) \($1.limitedRiskPremium.unit)")
            $0.append("details", $1.details)
            $0.append("sprint market", $1.sprintMarket) {
                $0.append("min expiration dates", $1.minExpirationDate, formatter: dayMonthYear)
                $0.append("max expiration dates", $1.maxExpirationDate, formatter: dayMonthYear)
            }
        }
        result.append("dealing rules", self.rules) {
            $0.append("market order preferences", $1.marketOrder)
            $0.append("min deal size", "\($1.minimumDealSize.value) \($1.minimumDealSize.unit)")
            $0.append("limit distance", "\($1.limit.mininumDistance.value)  \($1.limit.mininumDistance.unit)...\($1.limit.maximumDistance.value) \($1.limit.maximumDistance.unit)")
            $0.append("stop", $1.stop) {
                $0.append("distance", "\($1.mininumDistance.value) \($1.mininumDistance.unit)...\($1.maximumDistance.value) \($1.maximumDistance.unit)")
                $0.append("guaranteed stop distance", "\($1.minimumLimitedRiskDistance.value) \($1.minimumLimitedRiskDistance.unit)...\($1.maximumDistance.value) \($1.maximumDistance.unit)")
                $0.append("are trailing available", $1.trailing.areAvailable)
                $0.append("trailing minimum step", "\($1.trailing.minimumIncrement.value) \($1.trailing.minimumIncrement.unit)")
            }
        }
        result.append("snapshot", self.snapshot) {
            $0.append("date", $1.date, formatter: dateTime)
            $0.append("delay", "\($1.delay) (minutes)")
            $0.append("status", $1.status)
            $0.append("price", $1.price) {
                $0.append("ask", $1.ask)
                $0.append("bid", $1.bid)
                $0.append("range", "\($1.lowest)...\($1.highest)")
                $0.append("change", "\($1.change.net) (net) or \($1.change.percentage) %")
            }
            $0.append("scaling factor", $1.scalingFactor)
            $0.append("decimal places (for levels)", $1.decimalPlacesFactor)
            $0.append("guaranteed stop extra spread", $1.extraSpreadForControlledRisk)
            $0.append("binary odds", $1.binaryOdds)
        }
        return result.generate()
    }
}
