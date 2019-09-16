import ReactiveSwift
import Foundation
import SQLite3

extension IG.DB.Request.Markets {
    internal func getAll(forexMarketsOn channel: SQLite.Database, permission: IG.DB.Request.Expiration) -> IG.DB.Response<[IG.DB.Market.Forex]> {
        var statement: SQLite.Statement? = nil
        defer { sqlite3_finalize(statement) }
        
        let query = "SELECT * FROM Forex;"
        if let compileError = sqlite3_prepare_v2(channel, query, -1, &statement, nil).enforce(.ok) {
            return .failure(error: .callFailed(.querying(IG.DB.Application.self), code: compileError))
        }
        
        var result: [IG.DB.Market.Forex] = .init()
        repeat {
            switch sqlite3_step(statement).result {
            case .row:  result.append(.init(statement: statement!))
            case .done: return .success(value: result)
            case let e: return .failure(error: .callFailed(.querying(IG.DB.Application.self), code: e))
            }
        } while permission().isAllowed
        
        return .interruption
    }
    
    /// Updates the database with the information received from the server.
    ///
    /// This method is intended to be called from the generic update markets. That is why, no transaction is performed here, since the parent method will wrap everything in its own transaction.
    /// - precondition: The market must be of currency type or an error will be returned.
    /// - parameter markets: The currency markets to be updated.
    /// - parameter continueOnError: The parameter `markets` may contain other markets that are not forex markets (e.g. crypto currencies, commodities, etc.). Setting this argument to `true` won't throw an error when one of those markets are encountered and it will continue updating the rest.
    internal func update(forexMarkets markets: [IG.API.Market], continueOnError: Bool, channel: SQLite.Database, permission: IG.DB.Request.Expiration) -> IG.DB.Response<Void> {
        var statement: SQLite.Statement? = nil
        defer { sqlite3_finalize(statement) }
        
        let query = """
            INSERT INTO Forex VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22, ?23)
                ON CONFLICT(epic) DO UPDATE SET
                    base=excluded.base, counter=excluded.counter,
                    name=excluded.name, marketId=excluded.marketId, chartId=excluded.chartId, reutersId=excluded.reutersId,
                    contSize=excluded.contSize, pipVal=excluded.pipVal, placePip=excluded.placePip, placeLevel=excluded.placeLevel, slippage=excluded.slippage, premium=excluded.premium, extra=excluded.extra, margin=excluded.margin, bands=excluded.bands,
                    minSize=excluded.minSize, minDista=excluded.minDista, maxDista=excluded.maxDista, minRisk=excluded.minRisk, riskUnit=excluded.riskUnit, trailing=excluded.trailing, minStep=excluded.minStep;
            """
        if let compileError = sqlite3_prepare_v2(channel, query, -1, &statement, nil).enforce(.ok) {
            return .failure(error: .callFailed(.storing(IG.DB.Market.Forex.self), code: compileError))
        }
        
        for m in markets {
            guard case .continue = permission() else { return .interruption }
 
            switch IG.DB.Market.Forex.inferred(from: m) {
            case .failure(let error):
                if continueOnError { continue }
                else { return .failure(error: error) }
            case .success(let inferred):
                // The pip value can also be inferred from: `instrument.pip.value`
                let forex = IG.DB.Market.Forex(epic: m.instrument.epic, currencies: .init(base: inferred.base, counter: inferred.counter),
                                               identifiers: .init(name: m.instrument.name, market: inferred.marketId, chart: m.instrument.chartCode, reuters: m.instrument.newsCode),
                                               information: .init(contractSize: Int(clamping: inferred.contractSize),
                                                                  pip: .init(value: Int(clamping: m.instrument.lotSize), decimalPlaces: Int(log10(Double(m.snapshot.scalingFactor)))),
                                                                  levelDecimalPlaces: m.snapshot.decimalPlacesFactor,
                                                                  slippageFactor: m.instrument.slippageFactor.value,
                                                                  guaranteedStop: .init(premium: m.instrument.limitedRiskPremium.value, extraSpread: m.snapshot.extraSpreadForControlledRisk),
                                                                  margin: .init(factor: m.instrument.margin.factor, depositBands: inferred.bands)),
                                               restrictions: .init(minimumDealSize: m.rules.minimumDealSize.value,
                                                                   regularDistance: .init(minimum: m.rules.limit.mininumDistance.value, maximumAsPercentage: m.rules.limit.maximumDistance.value),
                                                                   guarantedStopDistance: .init(minimumValue: m.rules.stop.minimumLimitedRiskDistance.value,
                                                                                                minimumUnit: inferred.guaranteedStopUnit,
                                                                                                maximumAsPercentage: m.rules.limit.maximumDistance.value),
                                                                   trailingStop: .init(isAvailable: m.rules.stop.trailing.areAvailable, minimumIncrement: m.rules.stop.trailing.minimumIncrement.value)))
                forex.bind(to: statement!)
            }
            
            if let updateError = sqlite3_step(statement).enforce(.done) {
                return .failure(error: .callFailed(.storing(IG.DB.Application.self), code: updateError))
            }
            
            sqlite3_clear_bindings(statement)
            sqlite3_reset(statement)
        }
        
        return .success(value: ())
    }
}

// MARK: - Entities

extension IG.DB.Market {
    /// Database representation of a Foreign Exchange market.
    public struct Forex {
        /// Instrument identifier.
        public let epic: IG.Market.Epic
        /// The two currencies involved in this forex market.
        public let currencies: Self.Currencies
        /// Group of codes identifying this Forex market depending on context.
        public let identifiers: Self.Identifiers
        /// Basic information to calculate all values when dealing on this Forex market.
        public let information: Self.DealingInformation
        /// Restrictions while dealing on this market.
        public let restrictions: Self.Restrictions
    }
}

extension IG.DB.Market.Forex {
    /// The base and counter currencies of a foreign exchange market.
    public struct Currencies {
        /// The traditionally "strong" currency.
        public let base: IG.Currency.Code
        /// The traditionally "weak" currency (on which the units are measured).
        public let counter: IG.Currency.Code
    }

    /// Identifiers for a Forex markets.
    public struct Identifiers {
        /// Instrument name.
        public let name: String
        /// The name of a natural grouping of a set of IG markets.
        ///
        /// It typically represents the underlying 'real-world' market (normal and mini markets share the same identifier).
        /// This identifier is primarily used in our market research services, such as client sentiment, and may be found on the /market/{epic} service
        public let market: String
        /// Chart code.
        public let chart: String?
        /// Retuers news code.
        public let reuters: String
    }

    /// Specific information for the given Forex market.
    public struct DealingInformation {
        /// The amount of counter currency per contract.
        ///
        /// For example, the EUR/USD market has a contract size of $100,000 per contract.
        public let contractSize: Int
        /// Basic information about "Price Interest Point".
        public let pip: Self.Pip
        /// Number of decimal positions for market levels.
        public let levelDecimalPlaces: Int
        /// Slippage is the difference between the level of a stop order and the actual price at which it was executed.
        ///
        /// It can occur during periods of higher volatility when market prices move rapidly or gap
        /// - note: It is expressed as a percentage (e.g. 50%).
        public let slippageFactor: Decimal
        /// Basic information about the "Guaranteed Stop" (or limited risk stop).
        public let guaranteedStop: Self.GuaranteedStop
        /// Margin information and requirements.
        public let margin: Self.Margin
        
        /// Price interest point.
        public struct Pip {
            /// What is the value of one pip (i.e. Price Interest Point).
            public let value: Int
            /// Number of decimal positions for pip representation.
            public let decimalPlaces: Int
        }
        
        /// Limited risk stop.
        public struct GuaranteedStop {
            /// The premium (indicated in points) "paid" for a *guaranteed stop*.
            public let premium: Decimal
            /// The number of points to add on each side of the market as an additional spread when placing a guaranteed stop trade.
            public let extraSpread: Decimal
        }
        
        /// Margin requirements and deposit bands.
        public struct Margin {
            /// Margin requirement factor.
            public let factor: Decimal
            /// Deposit bands.
            ///
            /// Its value is always expressed on the *counter* currency.
            public let depositBands: Self.Bands
            
            /// A band is a collection of ranges and its associated deposit factos (in `%`).
            ///
            /// All ranges are `RangeExpression`s where `Bound` is set to `Decimal`. The last range is of `PartialRangeFrom` type (because it includes the lower bound till infinity), while all previous ones are of `Range` type.
            public struct Bands: RandomAccessCollection {
                public typealias Element = (range: Any, depositFactor: Decimal)
                /// The underlying storage.
                fileprivate let storage: [Self.StoredElement]
            }
        }
    }

    /// Restrictions applied when dealing on a Forex market.
    public struct Restrictions {
        /// Minimum deal size (expressed in points).
        public let minimumDealSize: Decimal
        /// Minimum and maximum distances for limits and normal stops
        fileprivate let regularDistance: Self.Distance.Regular
        /// Minimum and maximum allowed stops (limited risk).
        public let guarantedStopDistance: Self.Distance.Variable
        /// Restrictions related to trailing stops.
        public let trailingStop: Self.TrailingStop
        
        /// Minimum and maximum allowed limits.
        public var limitDistance: Self.Distance.Regular { self.regularDistance }
        /// Minimum and maximum allowed stops (exposed risk).
        public var stopDistance: Self.Distance.Regular { self.regularDistance }
        
        /// Minimum and maximum values for diatances.
        public struct Distance {
            /// Distances where the minimum is always expressed in points and the maximum as percentage.
            public struct Regular {
                /// The minimum distance (expressed in pips).
                public let minimum: Decimal
                /// The maximum allowed distance (expressed as percentage)
                public let maximumAsPercentage: Decimal
            }
            /// Distances where the minimum can be expressed in points or percentage, but the maximum is always expressed in percentage.
            public struct Variable {
                /// The minimum distance (expressed in pips).
                public let minimumValue: Decimal
                /// The unit on which the `minimumValue` is expressed as.
                public let minimumUnit: IG.DB.Unit
                /// The maximum allowed distance (expressed as percentage)
                public let maximumAsPercentage: Decimal
            }
        }
        
        /// Restrictions related to trailing stops.
        public struct TrailingStop {
            /// Whether trailing stops are available.
            public let isAvailable: Bool
            /// Minimum trailing stop increment expressed (in pips).
            public let minimumIncrement: Decimal
        }
    }
}

// MARK: - Functionality

// MARK: SQLite

extension IG.DB.Market.Forex: DBMigratable {
    internal static func tableDefinition(for version: DB.Migration.Version) -> String? {
        switch version {
        case .v0: return """
            CREATE TABLE Forex (
                epic       TEXT    NOT NULL UNIQUE CHECK( LENGTH(epic) BETWEEN 6 AND 30 ),
                base       TEXT    NOT NULL        CHECK( LENGTH(base) == 3 ),
                counter    TEXT    NOT NULL        CHECK( LENGTH(counter) == 3 ),
            
                name       TEXT    NOT NULL UNIQUE CHECK( LENGTH(name) > 0 ),
                marketId   TEXT    NOT NULL        CHECK( LENGTH(marketId) > 0 ),
                chartId    TEXT                    CHECK( LENGTH(chartId) > 0 ),
                reutersId  TEXT    NOT NULL        CHECK( LENGTH(reutersId) > 0 ),
            
                contSize   INTEGER NOT NULL        CHECK( contSize > 0 ),
                pipVal     INTEGER NOT NULL        CHECK( pipVal > 0 ),
                placePip   INTEGER NOT NULL        CHECK( placePip >= 0 ),
                placeLevel INTEGER NOT NULL        CHECK( placeLevel >= 0 ),
                slippage   INTEGER NOT NULL        CHECK( slippage >= 0 ),
                premium    INTEGER NOT NULL        CHECK( premium >= 0 ),
                extra      INTEGER NOT NULL        CHECK( extra >= 0 ),
                margin     INTEGER NOT NULL        CHECK( margin >= 0 ),
                bands      TEXT    NOT NULL        CHECK( LENGTH(bands) > 0 ),
            
                minSize    INTEGER NOT NULL        CHECK( minSize >= 0 ),
                minDista   INTEGER NOT NULL        CHECK( minDista >= 0 ),
                maxDista   INTEGER NOT NULL        CHECK( maxDista >= 0 ),
                minRisk    INTEGER NOT NULL        CHECK( minRisk >= 0 ),
                riskUnit   INTEGER NOT NULL        CHECK( trailing BETWEEN 0 AND 1 ),
                trailing   INTEGER NOT NULL        CHECK( trailing BETWEEN 0 AND 1 ),
                minStep    INTEGER NOT NULL        CHECK( minStep >= 0 ),
            
                CHECK( base != counter ),
                FOREIGN KEY(epic) REFERENCES Markets(epic)
            );
            """
        }
    }
}

fileprivate extension IG.DB.Market.Forex {
    typealias Indices = (epic: Int32, base: Int32, counter: Int32, identifiers: Self.Identifiers.Indices, information: Self.DealingInformation.Indices, restrictions: Self.Restrictions.Indices)
    
    init(statement s: SQLite.Statement, indices: Self.Indices = (0, 1, 2, (3, 4, 5, 6), (7, 8, 9, 10, 11, 12, 13, 14, 15), (16, 17, 18, 19, 20, 21, 22)) ) {
        self.epic = IG.Market.Epic(rawValue: String(cString: sqlite3_column_text(s, indices.epic)))!
        self.currencies = .init(base:    IG.Currency.Code(rawValue: String(cString: sqlite3_column_text(s, indices.base)))!,
                                counter: IG.Currency.Code(rawValue: String(cString: sqlite3_column_text(s, indices.counter)))!)
        self.identifiers  = .init(statement: s, indices: indices.identifiers)
        self.information  = .init(statement: s, indices: indices.information)
        self.restrictions = .init(statement: s, indices: indices.restrictions)
    }
    
    
    func bind(to statement: SQLite.Statement, indices: Self.Indices = (1, 2, 3, (4, 5, 6, 7), (8, 9, 10, 11, 12, 13, 14, 15, 16), (17, 18, 19, 20, 21, 22, 23))) {
        sqlite3_bind_text(statement, indices.epic, self.epic.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, indices.base, self.currencies.base.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, indices.counter, self.currencies.counter.rawValue, -1, SQLITE_TRANSIENT)
        self.identifiers.bind(to: statement, indices: indices.identifiers)
        self.information.bind(to: statement, indices: indices.information)
        self.restrictions.bind(to: statement, indices: indices.restrictions)
    }
}

fileprivate extension IG.DB.Market.Forex.Identifiers {
    typealias Indices = (name: Int32, market: Int32, chart: Int32, reuters: Int32)
    
    init(statement: SQLite.Statement, indices: Self.Indices) {
        self.name = String(cString: sqlite3_column_text(statement, indices.name))
        self.market = String(cString: sqlite3_column_text(statement, indices.market))
        self.chart = sqlite3_column_text(statement, indices.chart).map { String(cString: $0) }
        self.reuters = String(cString: sqlite3_column_text(statement, indices.reuters))
    }
    
    func bind(to statement: SQLite.Statement, indices: Self.Indices) {
        sqlite3_bind_text(statement, indices.name, self.name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, indices.market, self.market, -1, SQLITE_TRANSIENT)
        switch self.chart {
        case let c?: sqlite3_bind_text(statement, indices.chart, c, -1, SQLITE_TRANSIENT)
        case .none:  sqlite3_bind_null(statement, indices.chart)
        }
        sqlite3_bind_text (statement, indices.reuters, self.reuters, -1, SQLITE_TRANSIENT)
    }
}

fileprivate extension IG.DB.Market.Forex.DealingInformation {
    typealias Indices = (contractSize: Int32, pipValue: Int32, pipPlaces: Int32, levelPlaces: Int32, slippage: Int32, premium: Int32, extra: Int32, factor: Int32, bands: Int32)
    
    init(statement: SQLite.Statement, indices: Self.Indices) {
        self.contractSize = Int(sqlite3_column_int64(statement, indices.contractSize))
        self.pip = .init(value: Int(sqlite3_column_int64(statement, indices.pipValue)),
                         decimalPlaces: Int(sqlite3_column_int(statement, indices.pipPlaces)))
        self.levelDecimalPlaces = Int(sqlite3_column_int(statement, indices.levelPlaces))
        self.slippageFactor = Decimal(sqlite3_column_int64(statement, indices.slippage), divingByPowerOf10: 1)
        self.guaranteedStop = .init(premium: Decimal(sqlite3_column_int64(statement, indices.premium), divingByPowerOf10: 2),
                                    extraSpread: Decimal(sqlite3_column_int64(statement, indices.extra), divingByPowerOf10: 2))
        self.margin = .init(factor: Decimal(sqlite3_column_int64(statement, indices.factor), divingByPowerOf10: 3),
                            depositBands: .init(underlying: String(cString: sqlite3_column_text(statement, indices.bands))))
    }
    
    func bind(to statement: SQLite.Statement, indices: Self.Indices) {
        sqlite3_bind_int64(statement, indices.contractSize, Int64(self.contractSize))
        sqlite3_bind_int64(statement, indices.pipValue,     Int64(self.pip.value))
        sqlite3_bind_int  (statement, indices.pipPlaces,    Int32(self.pip.decimalPlaces))
        sqlite3_bind_int  (statement, indices.levelPlaces,  Int32(self.levelDecimalPlaces))
        sqlite3_bind_int64(statement, indices.slippage,     Int64(clamping: self.slippageFactor, multiplyingByPowerOf10: 1))
        sqlite3_bind_int64(statement, indices.premium,      Int64(clamping: self.guaranteedStop.premium, multiplyingByPowerOf10: 2))
        sqlite3_bind_int64(statement, indices.extra,        Int64(clamping: self.guaranteedStop.extraSpread, multiplyingByPowerOf10: 2))
        sqlite3_bind_int64(statement, indices.factor,       Int64(clamping: self.margin.factor, multiplyingByPowerOf10: 3))
        sqlite3_bind_text (statement, indices.bands, self.margin.depositBands.encode(), -1, SQLITE_TRANSIENT)
    }
}

fileprivate extension IG.DB.Market.Forex.Restrictions {
    typealias Indices = (dealSize: Int32, minDistance: Int32, maxDistance: Int32, guaranteedStopDistance: Int32, guaranteedStopUnit: Int32, trailing: Int32, minStep: Int32)
    
    init(statement: SQLite.Statement, indices: Self.Indices) {
        self.minimumDealSize = Decimal(sqlite3_column_int64(statement, indices.dealSize), divingByPowerOf10: 2)
        self.regularDistance = .init(minimum: Decimal(sqlite3_column_int64(statement, indices.minDistance), divingByPowerOf10: 2),
                                     maximumAsPercentage: Decimal(sqlite3_column_int64(statement, indices.maxDistance), divingByPowerOf10: 1))
        self.guarantedStopDistance = .init(minimumValue: Decimal(sqlite3_column_int64(statement, indices.guaranteedStopDistance), divingByPowerOf10: 2),
                                           minimumUnit: IG.DB.Unit(rawValue: Int(sqlite3_column_int(statement, indices.guaranteedStopUnit)))!,
                                           maximumAsPercentage: self.regularDistance.maximumAsPercentage)
        self.trailingStop = .init(isAvailable: Bool(sqlite3_column_int(statement, indices.trailing)),
                                  minimumIncrement: Decimal(sqlite3_column_int64(statement, indices.minStep), divingByPowerOf10: 1))
    }
    
    func bind(to statement: SQLite.Statement, indices: Self.Indices) {
        sqlite3_bind_int64(statement, indices.dealSize,               Int64(clamping: self.minimumDealSize, multiplyingByPowerOf10: 2))
        sqlite3_bind_int64(statement, indices.minDistance,            Int64(clamping: self.regularDistance.minimum, multiplyingByPowerOf10: 2))
        sqlite3_bind_int64(statement, indices.maxDistance,            Int64(clamping: self.regularDistance.maximumAsPercentage, multiplyingByPowerOf10: 1))
        sqlite3_bind_int64(statement, indices.guaranteedStopDistance, Int64(clamping: self.guarantedStopDistance.minimumValue, multiplyingByPowerOf10: 2))
        sqlite3_bind_int  (statement, indices.guaranteedStopUnit,     Int32(self.guarantedStopDistance.minimumUnit.rawValue))
        sqlite3_bind_int  (statement, indices.trailing,               Int32(self.trailingStop.isAvailable))
        sqlite3_bind_int64(statement, indices.minStep,                Int64(clamping: self.trailingStop.minimumIncrement, multiplyingByPowerOf10: 1))
    }
}

// MARK: Margins

extension IG.DB.Market.Forex {
    /// Calculate the margin requirements for a given deal (identify by its size, price, and stop).
    ///
    /// IG may offer reduced margins on "tier 1" positions with a non-guaranteed stop (it doesn't apply to higher tiers/bands).
    /// - parameter dealSize: The size of a given position.
    public func margin(forDealSize dealSize: Decimal, price: Decimal, stop: IG.Deal.Stop?) -> Decimal {
        let marginFactor = self.information.margin.factor
        let contractSize = Decimal(self.information.contractSize)
        
        guard let stop = stop else {
            return dealSize * contractSize * price * marginFactor
        }
        
        let stopDistance: Decimal
        switch stop.type {
        case .distance(let distance): stopDistance = distance
        case .position(let level):    stopDistance = (level - price).magnitude
        }
        
        switch stop.risk {
        case .exposed:
            let marginNoStop = dealSize * contractSize * price * marginFactor
            let marginWithStop = (marginNoStop * self.information.slippageFactor) + (dealSize * contractSize * stopDistance)
            return min(marginNoStop, marginWithStop)
        case .limited(let premium):
            return (dealSize * contractSize * stopDistance) + (premium ?? self.information.guaranteedStop.premium)
        }
    }
}

extension IG.DB.Market.Forex.DealingInformation.Margin.Bands {
    fileprivate typealias StoredElement = (lowerBound: Decimal, value: Decimal)
    /// The character separators used in encoding/decoding.
    private static let separator: (numbers: Character, elements: Character) = (":", "|")
    
    /// Designated initializer.
    fileprivate init(underlying: String) {
        self.storage = underlying.split(separator: Self.separator.elements).map {
            let strings = $0.split(separator: Self.separator.numbers)
            guard strings.count == 2 else {
                let msg = #"The given forex margin band "\#(String($0))" is invalid since it contains \#(strings.count) elements. Only 2 are expected"#
                fatalError(msg)
            }
            guard let lowerBound = Decimal(string: String(strings[0])) else { fatalError() }
            guard let factor = Decimal(string: String(strings[1])) else { fatalError() }
            return (lowerBound, factor)
        }
        
        guard !self.storage.isEmpty else {
            fatalError("The given forex market since to have no margin bands. This behavior is not expected")
        }
    }
    
    /// Encodes the receiving margin bands into a single `String`.
    fileprivate func encode() -> String {
        return self.storage.map {
            var result = String()
            result.append($0.lowerBound.description)
            result.append(Self.separator.numbers)
            result.append($0.value.description)
            return result
        }.joined(separator: .init(Self.separator.elements))
    }

    public var startIndex: Int {
        return self.storage.startIndex
    }
    
    public var endIndex: Int {
        return self.storage.endIndex
    }
    
    public subscript(position: Int) -> (range: Any, depositFactor: Decimal) {
        let element = self.storage[position]
        let nextIndex = position + 1
        if nextIndex < self.storage.endIndex {
            let (upperBound, _) = self.storage[nextIndex]
            return (element.lowerBound..<upperBound, element.value)
        } else {
            return (element.lowerBound..., element.value)
        }
    }
    
    public func index(before i: Int) -> Int {
        return self.storage.index(before: i)
    }
    
    public func index(after i: Int) -> Int {
        return self.storage.index(after: i)
    }
    
    /// Returns the deposit factor (expressed as a percentage `%`).
    /// - parameter dealSize: The size of a given position.
    public func depositFactor(forDealSize dealSize: Decimal) -> Decimal {
        var result = self.storage[0].value
        for element in self.storage {
            guard dealSize >= element.lowerBound else { return result }
            result = element.value
        }
        return result
    }
    
    /// Returns the last band.
    public var last: (range: PartialRangeFrom<Decimal>, depositFactor: Decimal)? {
        return self.storage.last.map { (element) in
            return (element.lowerBound..., element.value)
        }
    }
}

// MARK: API

extension IG.DB.Market.Forex {
    /// Check whether the given API market instance is a valid Forex DB market and returns inferred values.
    static fileprivate func inferred(from market: IG.API.Market) -> Result<(base: IG.Currency.Code, counter: IG.Currency.Code, marketId: String, contractSize: Decimal, guaranteedStopUnit: IG.DB.Unit, bands: Self.DealingInformation.Margin.Bands),IG.DB.Error> {
        let error: (_ suffix: String) -> IG.DB.Error = {
            return .invalidRequest(.init(#"The API market "\#(market.instrument.epic)" \#($0)"#), suggestion: .reviewError)
        }
        // 1. Check the type is .currency
        guard market.instrument.type == .currencies else {
            return .failure(error(#"is not of "currency" type"#))
        }
        
        let codes: (base: IG.Currency.Code, counter: IG.Currency.Code)? = {
            // A. The safest value is the pip meaning. However, it is not always indicated
            if let pip = market.instrument.pip?.meaning {
                // The pip meaning is divided in the meaning number and the currencies.
                let components = pip.split(separator: " ")
                if components.count > 1 {
                    let codes = components[1].split(separator: "/")
                    if codes.count == 2, let counter = IG.Currency.Code(rawValue: .init(codes[0])),
                        let base = IG.Currency.Code(rawValue: .init(codes[1])) {
                        return (base, counter)
                    }
                }
            }
            // B. Check the market identifier
            if let marketId = market.identifier, marketId.count == 6 {
                if let base = IG.Currency.Code(rawValue: .init(marketId.prefix(3)) ),
                    let counter = IG.Currency.Code(rawValue: .init(marketId.suffix(3))) {
                    return (base, counter)
                }
            }
            // C. Check the epic
            let epicSplit = market.instrument.epic.rawValue.split(separator: ".")
            if epicSplit.count > 3 {
                let identifier = epicSplit[2]
                if let base = IG.Currency.Code(rawValue: .init(identifier.prefix(3)) ),
                    let counter = IG.Currency.Code(rawValue: .init(identifier.suffix(3))) {
                    return (base, counter)
                }
            }
            // Otherwise, return `nil` since the currencies couldn't be inferred.
            return nil
        }()
        // 2. Check that currencies can be actually inferred
        guard let currencies = codes else {
            return .failure(error(#"is not of "currency" type"#))
        }
        // 3. Check the market identifier
        guard let marketId = market.identifier else {
            return .failure(error("doesn't contain a market identifier"))
        }
        // 4. Check the contract size
        guard let contractSize = market.instrument.contractSize else {
            return .failure(error("doesn't contain a contract size"))
        }
        // 5. Check the slippage factor unit
        guard market.instrument.slippageFactor.unit == .percentage else {
            return .failure(error(#"has a slippage factor unit of "\#(market.instrument.slippageFactor.unit)" when ".percentage" was expected"#))
        }
        // 6. Check the guaranteed stop premium unit
        guard market.instrument.limitedRiskPremium.unit == .points else {
            return .failure(error(#"has a limit risk premium unit of "\#(market.instrument.limitedRiskPremium.unit)" when ".points" was expected"#))
        }
        // 7. Check the margin unit
        guard market.instrument.margin.unit == .percentage else {
            return .failure(error(#"has a margin unit of "\#(market.instrument.margin.unit)" when ".percentage" was expected"#))
        }
        // 8. Check the margin deposit bands
        let apiBands = market.instrument.margin.depositBands.sorted { $0.minimum < $1.minimum }
        
        guard let code = apiBands.first?.currencyCode else {
            return .failure(error(#"doesn't have margin bands"#))
        }
        
        guard apiBands.allSatisfy({ $0.currencyCode == code }) else {
            return .failure(error(#"margin bands have different currency units"#))
        }
        
        for index in 0..<apiBands.count-1 {
            guard let max = apiBands[index].maximum else {
                let representation = apiBands.map { "\($0.minimum)..<\($0.maximum.map { String(describing: $0) } ?? "max") \($0.currencyCode) -> \($0.margin)%" }.joined(separator: ", ")
                return .failure(error(#"expected a maximum at index "\#(index)" for deposit bands [\#(representation)]"#))
            }
            
            guard max == apiBands[index+1].minimum else {
                let representation = apiBands.map { "\($0.minimum)..<\($0.maximum.map { String(describing: $0) } ?? "max") \($0.currencyCode) -> \($0.margin)%" }.joined(separator: ", ")
                return .failure(error(#"doesn't have contiguous deposit bands [\#(representation)]"#))
            }
        }
        
        let bands = Self.DealingInformation.Margin.Bands(storage: apiBands.map { ($0.minimum, $0.margin) })
        // 9. Check the minimum deal size units.
        guard market.rules.minimumDealSize.unit == .points else {
            return .failure(error(#"has a minimum deal size unit of "\#(market.rules.limit.mininumDistance.unit)" when ".points" was expected"#))
        }
        
        // 10. Check the limit units (they are the same as the stop units).
        guard market.rules.limit.mininumDistance.unit == .points else {
            return .failure(error(#"has a minimum limit distance unit of "\#(market.rules.limit.mininumDistance.unit)" when ".points" was expected"#))
        }
        
        guard market.rules.limit.maximumDistance.unit == .percentage else {
            return .failure(error(#"has a maximum limit distance unit of "\#(market.rules.limit.maximumDistance.unit)" when ".percentage" was expected"#))
        }
        // 11. Check the guaranteed stop units.
        let unit: IG.DB.Unit
        switch market.rules.stop.minimumLimitedRiskDistance.unit {
        case .points: unit = .points
        case .percentage: unit = .percentage
        }
        // 12. Check the trailing units.
        guard market.rules.stop.trailing.minimumIncrement.unit == .points else {
            return .failure(error(#"has a minimum trailing step increment unit of "\#(market.rules.stop.trailing.minimumIncrement.unit)" when ".points" was expected"#))
        }
        
        return .success((currencies.base, currencies.counter, marketId, contractSize, unit, bands))
    }
}

// MARK: Debugging

extension IG.DB.Market.Forex: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return IG.DB.Market.printableDomain.appending(".\(Self.self)")
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("epic", self.epic.rawValue)
        result.append("currencies", "\(self.currencies.base)/\(self.currencies.counter)")
        result.append("identifiers", self.identifiers) {
            $0.append("name", $1.name)
            $0.append("market", $1.market)
            $0.append("chart code", $1.chart)
            $0.append("news code", $1.reuters)
        }
        result.append("information", self.information) {
            $0.append("contract size", $1.contractSize)
            $0.append("pip value", $1.pip.value)
            $0.append("decimal places", "(level: \($1.levelDecimalPlaces), pip: \($1.pip.decimalPlaces)")
            $0.append("slippage factor", $1.slippageFactor)
            $0.append("guaranteed stop", "(premium: \($1.guaranteedStop.premium), extra spread: \($1.guaranteedStop.extraSpread)")
            $0.append("margin", $1.margin) {
                $0.append("factor", $1.factor)
                $0.append("deposit bands (range: factor)", $1.depositBands) {
                    for (range, depositFactor) in $1 {
                        $0.append(String(describing: range), depositFactor)
                    }
                    $0.append("paco", $1.startIndex)
                }
            }
        }
        result.append("restrictions", self.restrictions) {
            $0.append("deal size", "\($1.minimumDealSize)...")
            $0.append("limit distance", "\($1.limitDistance.minimum)pips...\($1.limitDistance.maximumAsPercentage)%")
            $0.append("stop distance (regular)", "\($1.stopDistance.minimum)pips...\($1.stopDistance.maximumAsPercentage)%")
            $0.append("stop distance (guaranteed)", "\($1.guarantedStopDistance.minimumValue)\($1.guarantedStopDistance.minimumUnit.debugDescription)...\($1.guarantedStopDistance.maximumAsPercentage)%")
            $0.append("trailing stop", "\($1.trailingStop.isAvailable ? IG.DebugDescription.Symbol.true : IG.DebugDescription.Symbol.false) increment from \($1.trailingStop.minimumIncrement)")
        }
        return result.generate()
    }
}
