import GRDB
import Foundation

extension IG.DB.Market {
    /// Database representation of a Foreign Exchange market.
    public struct Forex: GRDB.FetchableRecord {
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
        
        public init(row: GRDB.Row) {
            self.epic = row[0]
            self.currency = (base: row[1],
                             counter: row[2])
            self.identifiers = Self.Identifiers(
                                name: row[3],
                                market: row[4],
                                chart: row[5],
                                reuters: row[6])
            self.information = Self.DealingInformation(
                                contractSize: row[7],
                                pipValue: row[8],
                                pipPlaces: row[9],
                                levelPlaces: row[10],
                                slippage: row[11],
                                premium: row[12],
                                extra: row[13])
            self.restrictions = Self.Restrictions(
                                size: row[14],
                                normalDistance: row[15],
                                limitedRiskDistance: row[16],
                                maxDistance: row[17],
                                minStep: row[18])
            self.margin = Self.Margin(
                                factor: row[19],
                                band: row[20])
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
        /// The number of contracts you wish to trade or of open positions.
        public let contractSize: Int
        /// What is the value of one pip (i.e. Price Interest Point).
        public let pipValue: Int
        /// Number of decimal positions for pip representation.
        public let pipDecimalPlaces: Int   ;#warning("Test all markets: onePipMeans - 10^this == 0")   // This is "log(scalingFactor) / log(10)"
        /// Number of decimal positions for market levels.
        public let levelDecimalPlaces: Int ;#warning("Test all markets: scalingFactor - 10^this == 0") // This is "decimalPlaces"
        /// Slippage is the difference between the level of a stop order and the actual price at which it was executed.
        ///
        /// It can occur during periods of higher volatility when market prices move rapidly or gap
        /// - note: It is expressed as a percentage `%`.
        public let slippageFactor: Decimal  ;#warning(#"Test all markets: slippageFactor.unit == "pct""#)
        /// The premium (indicated in points) "paid" for a *guaranteed stop*.
        public let guaranteedStopPremium: Decimal ;#warning(#"Test all markets: limitedRiskPremium.unit == "POINTS""#) // This is "instrument.limitedRiskPremium"
        /// The number of points to add on each side of the market as an additional spread when placing a guaranteed stop trade.
        public let guaranteedStopExtraSpread: Decimal   // This is "snapshot.controlledRiskExtraSpread"
        /// Designated initializer
        fileprivate init(contractSize: Int, pipValue: Int, pipPlaces: Int, levelPlaces: Int, slippage: Int, premium: Int, extra: Int) {
            self.contractSize = contractSize
            self.pipValue = pipValue
            self.pipDecimalPlaces = pipPlaces
            self.levelDecimalPlaces = levelPlaces
            
            let power = IG.DB.Market.Forex.Power.factor
            self.slippageFactor = Decimal(slippage, divingByPowerOf10: power)
            self.guaranteedStopPremium = Decimal(premium, divingByPowerOf10: power)
            self.guaranteedStopExtraSpread = Decimal(extra, divingByPowerOf10: power)
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
            /// The character separators used in encoding/decoding.
            private static let separator: (numbers: Character, elements: Character) = (":", "|")
            /// The underlying storage.
            fileprivate let storage: [(lowerBound: Decimal, factor: Decimal)]
            
            /// Designated initializer.
            fileprivate init(underlying: String) {
                self.storage = underlying.split(separator: Self.separator.elements).map {
                    let strings = $0.split(separator: Self.separator.numbers)
                    guard strings.count == 2 else {
                        let msg = #"The given forex margin band "\#(String($0))" is invalid since it contains \#(strings.count) elements. Only 2 are expected."#
                        fatalError(msg)
                    }
                    guard let lowerBound = Decimal(string: String(strings[0])) else { fatalError() }
                    guard let factor = Decimal(string: String(strings[1])) else { fatalError() }
                    return (lowerBound, factor)
                }

                guard !self.storage.isEmpty else {
                    fatalError("The given forex market since to have no margin bands. This behavior is not expected.")
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
    
    /// Restrictions applied when dealing on a Forex market.
    public struct Restrictions {
        /// Minimum deal size.
        public let minimumSize: Decimal     ;#warning("Test all markets: instrument.lotSize == rules.minDealSize == this")    // This is "lotSize"
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
            self.minimumSize = Decimal(size, divingByPowerOf10: power)
            
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
            public let maximumAsPercentage: Decimal ;#warning("what does the percentage represent?")
            
            fileprivate init(min: Decimal, max: Decimal) {
                self.minimum = min
                self.maximumAsPercentage = max
            }
            
            #warning("Have a function returning a range in points and taking what it is acting on the percentage")
        }
    }
}

// MARK: - GRDB functionality

extension IG.DB.Market.Forex {
    /// Creates a SQLite table for Forex markets.
    static func tableCreation(in db: GRDB.Database) throws {
        let greaterThanZero: (Column) -> SQLExpressible = { $0 > 0 }
        let equalOrgreaterThanZero: (Column) -> SQLExpressible = { $0 >= 0 }
        
        try db.create(table: "forex", ifNotExists: false, withoutRowID: true) { (t) in
            t.column("epic", .text)         .primaryKey()
            t.column("base", .text)         .notNull()
            t.column("counter", .text)      .notNull()
            t.column("name", .text)         .notNull().unique()
            t.column("marketId", .text)     .notNull()
            t.column("chartId", .text)      .notNull()
            t.column("reutersId", .text)    .notNull()
            t.column("contSize", .integer)  .notNull().check(greaterThanZero)
            t.column("pipVal", .integer)    .notNull().check(greaterThanZero)
            t.column("placePip", .integer)  .notNull().check(equalOrgreaterThanZero)
            t.column("placeLevel", .integer).notNull().check(equalOrgreaterThanZero)
            t.column("slippage", .integer)  .notNull().check(equalOrgreaterThanZero)
            t.column("premium", .integer)   .notNull().check(equalOrgreaterThanZero)
            t.column("extra", .integer)     .notNull().check(equalOrgreaterThanZero)
            t.column("minSize", .integer)   .notNull().check(greaterThanZero)
            t.column("minDista", .integer)  .notNull().check(greaterThanZero)
            t.column("minRisk", .integer)   .notNull().check(greaterThanZero)
            t.column("maxDista", .integer)  .notNull().check(greaterThanZero)
            t.column("minStep", .integer)   .notNull().check(greaterThanZero)
            t.column("margin", .integer)    .notNull().check(greaterThanZero)
            t.column("bands", .text)        .notNull()
            
            t.check(Self.Columns.currencyBase != Self.Columns.currencyCounter)
        }
    }
}

extension IG.DB.Market.Forex: GRDB.TableRecord {
    /// The table columns
    internal enum Columns: String, GRDB.ColumnExpression {
        case epic = "epic"
        case currencyBase = "base"
        case currencyCounter = "counter"
        
        case name = "name"
        case marketId = "marketId"
        case chartId = "chartId"
        case reutersId = "reutersId"
        
        case contractSize = "contSize"
        case pipValue = "pipVal"
        case decimalPlacesPip = "placePip"
        case decimalPlacesLevel = "placeLevel"
        case slippageFactor = "slippage"
        case guaranteedStopPremium = "premium"
        case guaranteedStopExtraSpread = "extra"
        
        case minimumSize = "minSize"
        case minimumDistance = "minDista"
        case minimumLimitedDistance = "minRisk"
        case maximumDistance = "maxDista"
        case minimumTrailingIncrement = "minStep"
        
        case marginFactor = "margin"
        case marginBands = "bands"
    }
    
    public static var databaseTableName: String {
        return "forex"
    }
    
    //public static var databaseSelection: [SQLSelectable] { [AllColumns()] }
}

extension IG.DB.Market.Forex: GRDB.PersistableRecord {
    public func encode(to container: inout PersistenceContainer) {
        container[Columns.epic] = self.epic
        container[Columns.currencyBase] = self.currency.base
        container[Columns.currencyCounter] = self.currency.counter
        
        container[Columns.name] = self.identifiers.name
        container[Columns.marketId] = self.identifiers.market
        container[Columns.chartId] = self.identifiers.chart
        container[Columns.reutersId] = self.identifiers.reuters
        
        let powerFactor = Self.Power.factor
        container[Columns.contractSize] = self.information.contractSize
        container[Columns.pipValue] = self.information.pipValue
        container[Columns.decimalPlacesPip] = self.information.pipDecimalPlaces
        container[Columns.decimalPlacesLevel] = self.information.levelDecimalPlaces
        container[Columns.slippageFactor] = Int(clamping: self.information.slippageFactor, multiplyingByPowerOf10: powerFactor)
        container[Columns.guaranteedStopPremium] = Int(clamping: self.information.guaranteedStopPremium, multiplyingByPowerOf10: powerFactor)
        container[Columns.guaranteedStopExtraSpread] = Int(clamping: self.information.guaranteedStopExtraSpread, multiplyingByPowerOf10: powerFactor)
        
        let powerRest = Self.Power.restrictions
        container[Columns.minimumSize] = Int(clamping: self.restrictions.minimumSize, multiplyingByPowerOf10: powerRest)
        container[Columns.minimumDistance] = Int(clamping: self.restrictions.limitDistance.minimum, multiplyingByPowerOf10: powerRest)
        container[Columns.minimumLimitedDistance] = Int(clamping: self.restrictions.guarantedStopDistance.minimum, multiplyingByPowerOf10: powerRest)
        container[Columns.maximumDistance] = Int(clamping: self.restrictions.limitDistance.maximumAsPercentage, multiplyingByPowerOf10: powerRest)
        container[Columns.minimumTrailingIncrement] = Int(clamping: self.restrictions.minimumTrailingStopIncrement, multiplyingByPowerOf10: powerRest)
        
        let powerMargin = Self.Power.factor
        container[Columns.marginFactor] = Int(clamping: self.margin.factor, multiplyingByPowerOf10: powerMargin)
        container[Columns.marginBands] = self.margin.depositBands.encode()
    }
    
    /// List of Tenth powers used to transform decimals into integers.
    private enum Power {
        static var factor: Int { 3 }
        static var restrictions: Int { 2 }
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
            let marginWithStop = (marginNoStop * self.information.slippageFactor) + (dealSize * contractSize * stopDistance)
            return min(marginNoStop, marginWithStop)
        case .limited(let premium):
            return (dealSize * contractSize * stopDistance) + (premium ?? self.information.guaranteedStopPremium)
        }
    }
}

extension IG.DB.Market.Forex.Margin.Bands {
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

extension IG.DB.Market.Forex.Margin.Bands {
    public typealias Element = (range: Any, depositFactor: Decimal)
    public typealias Index = Int
    
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
}
