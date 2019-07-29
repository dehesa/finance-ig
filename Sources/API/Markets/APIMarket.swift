import ReactiveSwift
import Foundation

extension API.Request.Markets {
    
    // MARK: GET /markets/{epic}
    
    /// Returns the details of a given market.
    /// - parameter epic: The market epic to target onto. It cannot be empty.
    /// - returns: Information about the targeted market.
    public func get(epic: Epic) -> SignalProducer<API.Market,API.Error> {
        let dateFormatter: DateFormatter = API.TimeFormatter.iso8601NoTimezoneSeconds.deepCopy
        
        return SignalProducer(api: self.api) { (api) in
                let timezone = try api.session.credentials?.timezone ?! API.Error.invalidCredentials(nil, message: "No credentials were found; thus, the user's timezone couldn't be inferred.")
                dateFormatter.timeZone = timezone
            }.request(.get, "markets/\(epic.rawValue)", version: 3, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON { (_,_) in
                let decoder = JSONDecoder()
                decoder.userInfo[API.JSON.DecoderKey.dateFormatter] = dateFormatter
                return decoder
            }
    }
    
    // MARK: GET /markets
    
    /// Returns the details of the given markets.
    /// - parameter epics: The market epics to target onto. It cannot be empty.
    /// - returns: Extended information of all the requested markets.
    public func get(epics: Set<Epic>) -> SignalProducer<[API.Market],API.Error> {
        let dateFormatter: DateFormatter = API.TimeFormatter.iso8601NoTimezoneSeconds
        
        return SignalProducer(api: self.api) { (api) in
            let errorBlurb = "Search for market epics failed!"
            guard !epics.isEmpty else {
                throw API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) There needs to be at least one epic defined.")
            }
            guard epics.count <= 50 else {
                throw API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) You cannot pass more than 50 epics.")
            }
            
            let timezone = try api.session.credentials?.timezone ?! API.Error.invalidCredentials(nil, message: "No credentials were found; thus, the user's timezone couldn't be inferred.")
            dateFormatter.timeZone = timezone
        }.request(.get, "markets", version: 2, credentials: true, queries: { (_,_) -> [URLQueryItem] in
            [URLQueryItem(name: "filter", value: "ALL"),
             URLQueryItem(name: "epics", value: epics.map { $0.rawValue }.joined(separator: ",")) ]
        }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON { (_,_) in
                let decoder = JSONDecoder()
                decoder.userInfo[API.JSON.DecoderKey.dateFormatter] = dateFormatter
                return decoder
            }.map { (list: Self.WrapperList) in list.marketDetails }
    }
}

// MARK: - Supporting Entities

extension API.Request {
    /// Contains all functionality related to API markets.
    public struct Markets {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        internal unowned let api: API
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoint.
        init(api: API) {
            self.api = api
        }
    }
}

// MARK: Response Entities

extension API.Request.Markets {
    private struct WrapperList: Decodable {
        let marketDetails: [API.Market]
    }
}

extension API {
    /// A financial market, which may refer to an underlying financial market, or the market being offered in terms of an IG instrument.
    ///
    /// IG instruments are organised in the form a navigable market hierarchy
    public struct Market: Decodable {
        /// The name of a natural grouping of a set of IG markets
        ///
        /// It typically represents the underlying 'real-world' market. For example, `VOD-UK` represents Vodafone Group PLC (UK).
        /// This identifier is primarily used in the our market research services, such as client sentiment, and may be found on the /market/{epic} service
        public let identifier: String
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
            self.identifier = try (instrumentContainer).decode(String.self, forKey: .identifier)
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

extension API.Market {
    /// Instrument details.
    public struct Instrument: Decodable {
        /// Instrument identifier.
        public let epic: Epic
        /// Instrument name.
        public let name: String
        /// Instrument type.
        public let type: API.Instrument
        /// Market expiration date details.
        public let expiration: Self.Expiration
        /// Country.
        public let country: String?
        /// Currencies.
        public let currencies: [Self.Currency]
        /// Market open and closes times.
        /// - todo: Not yet tested.
        public let openingTime: [Self.HourRange]?
        /// Unit used to qualify the size of a trade.
        public let unit: Self.Unit
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
        public let isControlledRiskAllowed: Bool
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
        /// Boolean indicating whether prices are available through streaming communications.
        public let isAvailableByStreaming: Bool
        /// Chart code.
        public let chartCode: String
        /// Retuers news code.
        public let newsCode: String
        /// List of special information notices.
        public let details: [String]?
        /// Properties of sprint markets.
        public let sprintMarket: Self.SprintMarket?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.epic = try container.decode(Epic.self, forKey: .epic)
            self.name = try container.decode(String.self, forKey: .name)
            self.type = try container.decode(API.Instrument.self, forKey: .type)
            self.expiration = try .init(from: decoder)
            self.country = try container.decodeIfPresent(String.self, forKey: .country)
            self.currencies = try container.decodeIfPresent(Array<Self.Currency>.self, forKey: .currencies) ?? []
            
            if let wrapper = try container.decodeIfPresent([String:Array<Self.HourRange>].self, forKey: .openingTime) {
                self.openingTime = try wrapper[Self.CodingKeys.openingMarketTimes.rawValue]
                    ?! DecodingError.dataCorruptedError(forKey: .openingTime, in: container, debugDescription: "Openning times wrapper key \"\(Self.CodingKeys.openingMarketTimes.rawValue)\" was not found.")
            } else {
                self.openingTime = nil
            }
            
            self.unit = try container.decode(Self.Unit.self, forKey: .unit)
            
            let pipMeaning = try container.decodeIfPresent(String.self, forKey: .pipMeaning)
            let pipValue = try container.decodeIfPresent(String.self, forKey: .pipValue)
            if let meaning = pipMeaning, let value = pipValue {
                self.pip = .init(meaning: meaning, value: value)
            } else if pipMeaning == nil, pipValue == nil {
                self.pip = nil
            } else {
                throw DecodingError.dataCorruptedError(forKey: .pipMeaning, in: container, debugDescription: "The pip definition is inconsistent.")
            }
            
            self.lotSize = try container.decode(Decimal.self, forKey: .lotSize)
            if let contractString = try container.decodeIfPresent(String.self, forKey: .contractSize) {
                self.contractSize = try Decimal(string: contractString)
                    ?! DecodingError.dataCorruptedError(forKey: .contractSize, in: container, debugDescription: "The contract size \"\(contractString)\" couldn't be parsed into a number.")
            } else {
                self.contractSize = nil
            }
            self.isForceOpenAllowed = try container.decode(Bool.self, forKey: .isForceOpenAllowed)
            self.isControlledRiskAllowed = try container.decode(Bool.self, forKey: .isControlledRiskAllowed)
            self.isStopLimitAllowed = try container.decode(Bool.self, forKey: .isStopLimitAllowed)
            self.margin = try .init(from: decoder)
            self.slippageFactor = try container.decode(Self.SlippageFactor.self, forKey: .slippageFactor)
            self.rollover = try container.decodeIfPresent(Self.Rollover.self, forKey: .rollover)
            self.limitedRiskPremium = try container.decode(API.Market.Distance.self, forKey: .limitedRiskPremium)
            self.isAvailableByStreaming = try container.decode(Bool.self, forKey: .isAvailableByStreaming)
            self.chartCode = try container.decode(String.self, forKey: .chartCode)
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
            case isControlledRiskAllowed = "controlledRiskAllowed"
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

extension API.Market.Instrument {
    /// Expiration date details.
    public struct Expiration: Decodable {
        /// Expiration date. The date (and sometimes time) at which a spreadbet or CFD will automatically close against some predefined market value should the bet remain open beyond its last dealing time. Some CFDs do not expire, and have an expiry of '-'. eg DEC-14, or DFB for daily funded bets.
        public let expiry: API.Instrument.Expiry
        /// The last dealing date.
        public let lastDealingDate: Date?
        /// Settlement information.
        public let settlementInfo: String?

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)

            self.expiry = try container.decodeIfPresent(API.Instrument.Expiry.self, forKey: .expirationDate) ?? .none
            guard container.contains(.expirationDetails), !(try container.decodeNil(forKey: .expirationDetails)) else {
                self.settlementInfo = nil
                self.lastDealingDate = nil; return
            }

            let nestedContainer = try container.nestedContainer(keyedBy: Self.CodingKeys.NestedKeys.self, forKey: .expirationDetails)
            self.settlementInfo = try nestedContainer.decodeIfPresent(String.self, forKey: .settlementInfo)
            
            let formatter = try decoder.userInfo[API.JSON.DecoderKey.dateFormatter] as? DateFormatter
                ?! DecodingError.dataCorruptedError(forKey: .lastDealingDate, in: nestedContainer, debugDescription: "The date formatter supposed to be passed as user info couldn't be found.")
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
        /// The dimension for a dealing rule value.
        public let unit: API.Market.Distance.Unit
        /// Margin requirement factor.
        public let factor: Decimal
        /// Deposit bands.
        public let depositBands: [Self.Band]

        private enum CodingKeys: String, CodingKey {
            case unit = "marginFactorUnit"
            case factor = "marginFactor"
            case depositBands = "marginDepositBands"
        }

        public struct Band: Decodable {
            /// The currency for this currency band factor calculation.
            public let currency: IG.Currency.Code
            /// Margin percentage.
            public let margin: Decimal
            /// Band minimum.
            public let min: Decimal
            /// Band maximum.
            public let max: Decimal?
            /// Do not call! The only way to initialize is through `Decodable`.
            private init?() { fatalError("Unaccessible initializer") }
        }
    }
    
    /// Distance/Size preference.
    public struct SlippageFactor: Decodable {
        public let unit: String
        public let value: Decimal
    }

    /// Instrument rollover details.
    public struct Rollover: Decodable {
        public let lastDate: Date
        public let info: String

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            guard let formatter = decoder.userInfo[API.JSON.DecoderKey.dateFormatter] as? DateFormatter else {
                throw DecodingError.dataCorruptedError(forKey: .lastDate, in: container, debugDescription: "The date formatter supposed to be passed as user info couldn't be found.")
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

            let hasMin = try container.decodeNil(forKey: .sprintMin)
            let hasMax = try container.decodeNil(forKey: .sprintMax)
            guard hasMin == hasMax else { throw DecodingError.dataCorruptedError(forKey: .sprintMax, in: container, debugDescription: "Sprint market has an invalid min/max range.") }
            guard hasMin == false else { return nil }

            self.minExpirationDate = try container.decode(Date.self, forKey: .sprintMin, with: API.TimeFormatter.monthYear)
            self.maxExpirationDate = try container.decode(Date.self, forKey: .sprintMax, with: API.TimeFormatter.monthYear)
        }

        private enum CodingKeys: String, CodingKey {
            case sprintMin = "sprintMarketsMinimumExpiryTime"
            case sprintMax = "sprintMarketsMaximumExpiryTime"
        }
    }
}

extension API.Market {
    /// Dealing rule preferences.
    public struct Rules: Decodable {
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
        
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.marketOrder = try container.decode(Self.Order.self, forKey: .marketOrder)
            self.minimumDealSize = try container.decode(API.Market.Distance.self, forKey: .minimumDealSize)
            self.limit = try .init(from: decoder)
            self.stop = try .init(from: decoder)
        }
        
        private enum CodingKeys: String, CodingKey {
            case marketOrder = "marketOrderPreference"
            case minimumDealSize = "minDealSize"
        }
        
        /// Market order trading preference.
        public enum Order: Decodable {
            /// Market orders are not allowed for the current site and/or instrument.
            case unavailable
            /// Market orders are allowed for the account type and instrument and the user has enabled market orders in their preferences.
            /// The user has also decided whether that should be the default.
            case available(isDefault: Bool)
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                let preference = try container.decode(String.self)
                
                switch preference {
                case "NOT_AVAILABLE": self = .unavailable
                case "AVAILABLE_DEFAULT_ON": self = .available(isDefault: true)
                case "AVAILABLE_DEFAULT_OFF": self = .available(isDefault: false)
                default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Market order preference \"\(preference)\" not recognized.")
                }
            }
        }
        
        /// Settings for positions' limits.
        public struct Limit: Decodable {
            /// Minimum normal limit distance.
            public let mininumDistance: API.Market.Distance
            /// Maximum limit distance.
            public let maximumDistance: API.Market.Distance
            
            private enum CodingKeys: String, CodingKey {
                case mininumDistance = "minNormalStopOrLimitDistance"
                case maximumDistance = "maxStopOrLimitDistance"
            }
        }
        
        /// Settings for positions' stops.
        public struct Stop: Decodable {
            /// Minimum normal stop distance.
            public let mininumDistance: API.Market.Distance
            /// Minimum controller risk stop distance.
            public let minimumControlledRiskDistance: API.Market.Distance
            /// Maximum stop distance.
            public let maximumDistance: API.Market.Distance
            /// Trailing stops' settings.
            public let trailing: Self.Trailing
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: Self.CodingKeys.self)
                self.mininumDistance = try container.decode(API.Market.Distance.self, forKey: .mininumDistance)
                self.minimumControlledRiskDistance = try container.decode(API.Market.Distance.self, forKey: .minimumControlledRiskDistance)
                self.maximumDistance = try container.decode(API.Market.Distance.self, forKey: .maximumDistance)
                self.trailing = try .init(from: decoder)
            }
            
            private enum CodingKeys: String, CodingKey {
                case mininumDistance = "minNormalStopOrLimitDistance"
                case minimumControlledRiskDistance = "minControlledRiskStopDistance"
                case maximumDistance = "maxStopOrLimitDistance"
            }
            
            /// Settings for positions' trailing stops.
            public struct Trailing: Decodable {
                /// Trailing stops trading preference.
                public let areAvailable: Bool
                /// Minimum step distance.
                public let minimumIncrement: API.Market.Distance
                
                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: Self.CodingKeys.self)
                    self.minimumIncrement = try container.decode(API.Market.Distance.self, forKey: .minimumIncrement)
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

extension API.Market {
    /// Market snapshot data.
    public struct Snapshot: Decodable {
        /// Time of the last price update.
        /// - attention: Although a full date is given, only the hours:minutes:seconds are meaningful.
        public let date: Date
        /// Pirce delay marked in minutes.
        public let delay: TimeInterval
        /// The current status of a given market
        public let status: API.Market.Status
        /// The state of the market price at the time of the snapshot.
        public let price: API.Market.Price
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
            
            let responseDate = decoder.userInfo[API.JSON.DecoderKey.responseDate] as? Date ?? Date()
            let timeDate = try container.decode(Date.self, forKey: .lastUpdate, with: API.TimeFormatter.time)
            
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
            
            self.delay = try container.decode(TimeInterval.self, forKey: .delay)
            self.status = try container.decode(API.Market.Status.self, forKey: .status)
            self.price = try .init(from: decoder)
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

extension API.Market {
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
