import ReactiveSwift
import Foundation
import SQLite3

extension IG.DB.Request.Markets {
    /// Updates the database with the information received from the server.
    ///
    /// This method is intended to be called from the generic update markets. That is why, no transaction is performed here, since the parent method will wrap everything in its own transaction.
    /// - precondition: The market must be of currency type or an error will be returned.
    /// - parameter markets: The currency markets to be updated.
    internal func update(forexMarkets markets: [IG.API.Market], channel: SQLite.Database, permission: IG.DB.Request.Expiration) -> IG.DB.Response<Void> {
        var statement: SQLite.Statement? = nil
        defer { sqlite3_finalize(statement) }
        
        let query = """
            INSERT INTO Forex VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20)
                ON CONFLICT(epic) DO UPDATE SET
                    base = excluded.base, counter = excluded.counter,
                    name = excluded.name, marketId = excluded.marketId, chartId = excluded.chartId, reutersId = excluded.reutersId,
                    contSize = excluded.contSize, pipVal = excluded.pipVal, placePip = excluded.placePip, placeLevel = excluded.placeLevel, slippage = excluded.slippage, premium = excluded.premium, extra = excluded.extra,
                    minSize = excluded.minSize, minDista = excluded.minDista, minRisk = excluded.minRisk, maxDista = excluded.maxDista, minStep = excluded.minStep,
                    margin = excluded.margin, bands = excluded.bands;
            """
        if let compileError = sqlite3_prepare_v2(channel, query, -1, &statement, nil).enforce(.ok) {
            return .failure(error: .callFailed(.storing(IG.DB.Market.Forex.self), code: compileError))
        }
        
        for market in markets {
            guard case .continue = permission() else { return .interruption }
            sqlite3_reset(statement)
            
            sqlite3_bind_text (statement, 1, market.instrument.epic.rawValue, -1, SQLITE_TRANSIENT)
//            sqlite3_bind_int(statement, 2, Int32(<#T##Int32#>))
//
//            sqlite3_bind_int64(statement, <#T##Int32#>, Int64(<#T##sqlite3_int64#>))
//            sqlite3_bind_text (statement, <#T##Int32#>, <#T##UnsafePointer<Int8>!#>, -1, SQLITE_TRANSIENT)
            
            
            if let updateError = sqlite3_step(statement).enforce(.done) {
                return .failure(error: .callFailed(.storing(IG.DB.Application.self), code: updateError))
            }
            
            sqlite3_clear_bindings(statement)
        }
        
        return .success(value: ())
    }
}

// MARK: - Supporting Entities

// MARK: Response Entities

extension IG.DB.Market {
    /// Database representation of a Foreign Exchange market.
    public struct Forex {
        /// Instrument identifier.
        public let epic: IG.Market.Epic
        /// The currency base and counter for the receiving Forex market.
        public let currency: (base: IG.Currency.Code, counter: IG.Currency.Code)
        /// Group of codes identifying this Forex market depending on context.
        public let identifiers: Self.Identifiers
        /// Basic information to calculate all values when dealing on this Forex market.
        public let information: Self.DealingInformation
        /// Restrictions while dealing on this market.
        public let restrictions: Self.Restrictions
        /// Margin information and requirements.
        public let margin: Self.Margin
        
        /// Initializer when the instance comes directly from the database.
        fileprivate init(statement s: SQLite.Statement) {
            self.epic = IG.Market.Epic(rawValue: String(cString: sqlite3_column_text(s, 0)))!
            self.currency = (base:    IG.Currency.Code(rawValue: String(cString: sqlite3_column_text(s, 1)))!,
                             counter: IG.Currency.Code(rawValue: String(cString: sqlite3_column_text(s, 2)))!)
            self.identifiers = Self.Identifiers(name:    String(cString: sqlite3_column_text(s, 3)),
                                                market:  String(cString: sqlite3_column_text(s, 4)),
                                                chart:   String(cString: sqlite3_column_text(s, 5)),
                                                reuters: String(cString: sqlite3_column_text(s, 6)))
            self.information = Self.DealingInformation(contractSize: Int(sqlite3_column_int64(s,  7)),
                                                       pipValue:     Int(sqlite3_column_int64(s,  8)),
                                                       pipPlaces:    Int(sqlite3_column_int64(s,  9)),
                                                       levelPlaces:  Int(sqlite3_column_int64(s, 10)),
                                                       slippage:     Int(sqlite3_column_int64(s, 11)),
                                                       premium:      Int(sqlite3_column_int64(s, 12)),
                                                       extra:        Int(sqlite3_column_int64(s, 13)))
            self.restrictions = Self.Restrictions(size:                Int(sqlite3_column_int64(s, 14)),
                                                  normalDistance:      Int(sqlite3_column_int64(s, 15)),
                                                  limitedRiskDistance: Int(sqlite3_column_int64(s, 16)),
                                                  maxDistance:         Int(sqlite3_column_int64(s, 17)),
                                                  minStep:             Int(sqlite3_column_int64(s, 18)))
            self.margin = Self.Margin(factor: Int(sqlite3_column_int64(s, 19)),
                                      band:   String(cString: sqlite3_column_text(s, 20)))
        }
        
        /// List of Tenth powers used to transform decimals into integers.
        private enum Power {
            static var factor: Int { 3 }
            static var restrictions: Int { 2 }
        }
    }
}

extension IG.DB.Market.Forex {
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
        public let chart: String
        /// Retuers news code.
        public let reuters: String
        
        fileprivate init(name: String, market: String, chart: String, reuters: String) {
            self.name = name
            self.market = market
            self.chart = chart
            self.reuters = reuters
        }
    }
    
    /// Specific information for the given Forex market.
    public struct DealingInformation {
        /// The amount of counter currency per contract.
        ///
        /// For example, the EUR/USD market has a contract size of $100,000 per contract.
        public let contractSize: Int
        /// What is the value of one pip (i.e. Price Interest Point).
        public let pipValue: Int                                // This is both "lotSize" and pipValue
        /// Number of decimal positions for pip representation.
        public let pipDecimalPlaces: Int                        // This is "log(scalingFactor) / log(10)"
        /// Number of decimal positions for market levels.
        public let levelDecimalPlaces: Int                      // This is "decimalPlaces"
        /// Slippage is the difference between the level of a stop order and the actual price at which it was executed.
        ///
        /// It can occur during periods of higher volatility when market prices move rapidly or gap
        /// - note: It is expressed as a percentage (e.g. 50%).
        public let slippageFactor: Int
        /// The premium (indicated in points) "paid" for a *guaranteed stop*.
        public let guaranteedStopPremium: Decimal               // This is "instrument.limitedRiskPremium"
        /// The number of points to add on each side of the market as an additional spread when placing a guaranteed stop trade.
        public let guaranteedStopExtraSpread: Decimal           // This is "snapshot.controlledRiskExtraSpread"
        /// Designated initializer
        fileprivate init(contractSize: Int, pipValue: Int, pipPlaces: Int, levelPlaces: Int, slippage: Int, premium: Int, extra: Int) {
            self.contractSize = contractSize
            self.pipValue = pipValue
            self.pipDecimalPlaces = pipPlaces
            self.levelDecimalPlaces = levelPlaces
            self.slippageFactor = slippage
            
            let power = IG.DB.Market.Forex.Power.factor
            self.guaranteedStopPremium = Decimal(premium, divingByPowerOf10: power)
            self.guaranteedStopExtraSpread = Decimal(extra, divingByPowerOf10: power)
        }
    }
    
    /// Restrictions applied when dealing on a Forex market.
    public struct Restrictions {
        /// Minimum deal size (expressed in points).
        public let minimumDealSize: Decimal                     // This is "rules.minDealSize"
        /// Minimum and maximum allowed limits.
        public let limitDistance: Self.Distance
        /// Minimum and maximum allowed stops (exposed risk).
        public let stopDistance: Self.Distance
        /// Minimum and maximum allowed stops (limited risk).
        public let guarantedStopDistance: Self.Distance
        /// Minimum trailing stop increment expressed (in pips).
        public let minimumTrailingStopIncrement: Decimal
        /// Designated initializer
        fileprivate init(size: Int, normalDistance: Int, limitedRiskDistance: Int, maxDistance: Int, minStep: Int) {
            let power = IG.DB.Market.Forex.Power.restrictions
            self.minimumDealSize = Decimal(size, divingByPowerOf10: power)
            
            let minNormal = Decimal(normalDistance, divingByPowerOf10: power)
            let max = Decimal(maxDistance, divingByPowerOf10: power)
            self.limitDistance = Self.Distance(min: minNormal, max: max)
            self.stopDistance = Self.Distance(min: minNormal, max: max)
            
            let minRisk = Decimal(limitedRiskDistance, divingByPowerOf10: power)
            self.guarantedStopDistance = Self.Distance(min: minRisk, max: max)
            self.minimumTrailingStopIncrement = Decimal(minStep, divingByPowerOf10: power)
        }
        
        /// Minimum and maximum values for diatances.
        public struct Distance {
            /// The minimum distance (expressed in pips).
            public let minimum: Decimal
            /// The maximum allowed distance (expressed as percentage)
            public let maximumAsPercentage: Decimal
            
            fileprivate init(min: Decimal, max: Decimal) {
                self.minimum = min
                self.maximumAsPercentage = max
            }
        }
    }
    
    /// Margin requirements and deposit bands.
    public struct Margin {
        /// Margin requirement factor.
        public let factor: Decimal
        /// Deposit bands.
        ///
        /// Its value is always expressed on the *counter* currency.
        public let depositBands: Self.Bands
        /// Designated initializer
        fileprivate init(factor: Int, band: String) {
            let power = IG.DB.Market.Forex.Power.factor
            self.factor = Decimal(factor, divingByPowerOf10: power)
            self.depositBands = .init(underlying: band)
        }
        
        /// A band is a collection of ranges and its associated deposit factos (in `%`).
        ///
        /// All ranges are `RangeExpression`s where `Bound` is set to `Decimal`. The last range is of `PartialRangeFrom` type (because it includes the lower bound till infinity), while all previous ones are of `Range` type.
        public struct Bands: RandomAccessCollection {
            public typealias Element = (range: Any, depositFactor: Decimal)
            public typealias Index = Int
            
            /// The character separators used in encoding/decoding.
            private static let separator: (numbers: Character, elements: Character) = (":", "|")
            /// The underlying storage.
            fileprivate let storage: [(lowerBound: Decimal, factor: Decimal)]
            
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
                    result.append($0.factor.description)
                    return result
                }.joined(separator: .init(Self.separator.elements))
            }
        }
    }
}

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
                chartId    TEXT    NOT NULL        CHECK( LENGTH(chartId) > 0 ),
                reutersId  TEXT    NOT NULL        CHECK( LENGTH(reutersId) > 0 ),
                contSize   INTEGER NOT NULL        CHECK( contSize > 0 ),
                pipVal     INTEGER NOT NULL        CHECK( pipVal > 0 ),
                placePip   INTEGER NOT NULL        CHECK( placePip >= 0 ),
                placeLevel INTEGER NOT NULL        CHECK( placeLevel >= 0 ),
                slippage   INTEGER NOT NULL        CHECK( slippage >= 0 ),
                premium    INTEGER NOT NULL        CHECK( premium >= 0 ),
                extra      INTEGER NOT NULL        CHECK( extra >= 0 ),
                minSize    INTEGER NOT NULL        CHECK( minSize >= 0 ),
                minDista   INTEGER NOT NULL        CHECK( minDista >= 0 ),
                minRisk    INTEGER NOT NULL        CHECK( minRisk >= 0 ),
                maxDista   INTEGER NOT NULL        CHECK( maxDista >= 0 ),
                minStep    INTEGER NOT NULL        CHECK( minStep >= 0 ),
                margin     INTEGER NOT NULL        CHECK( margin >= 0 ),
                bands      TEXT    NOT NULL        CHECK( LENGTH(bands) > 0 ),
            
                CHECK( base != counter )
                FOREIGN KEY(epic) REFERENCES Markets(epic)
            );
            """
        }
    }
}

extension IG.DB.Market.Forex: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return IG.DB.Market.printableDomain.appending(".\(Self.self)")
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("epic", self.epic.rawValue)
        result.append("currencies", "\(self.currency.base)/\(self.currency.counter)")
        result.append("identifiers", self.identifiers) {
            $0.append("name", $1.name)
            $0.append("market", $1.market)
            $0.append("chart code", $1.chart)
            $0.append("news code", $1.reuters)
        }
        result.append("information", self.information) {
            $0.append("contract size", $1.contractSize)
            $0.append("pip value", $1.pipValue)
            $0.append("decimal places", "(level: \($1.levelDecimalPlaces), pip: \($1.pipDecimalPlaces)")
            $0.append("slippage factor", $1.slippageFactor)
            $0.append("guaranteed stop", "(premium: \($1.guaranteedStopPremium), extra spread: \($1.guaranteedStopExtraSpread)")
        }
        result.append("restrictions", self.restrictions) {
            $0.append("deal size", "\($1.minimumDealSize)...")
            $0.append("limit distance", "\($1.limitDistance.minimum)pips...\($1.limitDistance.maximumAsPercentage)%")
            $0.append("stop distance (regular)", "\($1.stopDistance.minimum)pips...\($1.stopDistance.maximumAsPercentage)%")
            $0.append("stop distance (guaranteed)", "\($1.guarantedStopDistance.minimum)pips...\($1.guarantedStopDistance.maximumAsPercentage)%")
            $0.append("trailing stop increment", "\($1.minimumTrailingStopIncrement)...")
        }
        result.append("margin", self.margin) {
            $0.append("factor", $1.factor)
            $0.append("deposit bands (range: factor)", $1.depositBands) {
                for (range, depositFactor) in $1 {
                    $0.append(String(describing: range), depositFactor)
                }
                $0.append("paco", $1.startIndex)
            }
        }
        return result.generate()
    }
}

// MARK: - Extra functionality

extension IG.DB.Market.Forex {
    /// Calculate the margin requirements for a given deal (identify by its size, price, and stop).
    ///
    /// IG may offer reduced margins on "tier 1" positions with a non-guaranteed stop (it doesn't apply to higher tiers/bands).
    /// - parameter dealSize: The size of a given position.
    public func margin(forDealSize dealSize: Decimal, price: Decimal, stop: IG.Deal.Stop?) -> Decimal {
        let marginFactor = self.margin.factor
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
            let marginWithStop = (marginNoStop * Decimal(self.information.slippageFactor)) + (dealSize * contractSize * stopDistance)
            return min(marginNoStop, marginWithStop)
        case .limited(let premium):
            return (dealSize * contractSize * stopDistance) + (premium ?? self.information.guaranteedStopPremium)
        }
    }
}

extension IG.DB.Market.Forex.Margin.Bands {
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
            return (element.lowerBound..<upperBound, element.factor)
        } else {
            return (element.lowerBound..., element.factor)
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
        var result = self.storage[0].factor
        for element in self.storage {
            guard dealSize >= element.lowerBound else { return result }
            result = element.factor
        }
        return result
    }
    
    /// Returns the last band.
    public var last: (range: PartialRangeFrom<Decimal>, depositFactor: Decimal)? {
        return self.storage.last.map { (element) in
            return (element.lowerBound..., element.factor)
        }
    }
}
