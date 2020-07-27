import Combine
import Decimals
import SQLite3

extension Database.Request.Markets {
    /// Contains all functionality related to Database Forex.
    @frozen public struct Forex {
        /// Pointer to the actual database instance in charge of the low-level objects.
        private unowned let _database: Database
        /// Hidden initializer passing the instance needed to perform the database fetches/updates.
        @usableFromInline internal init(database: Database) { self._database = database }
    }
}

extension Database.Request.Markets.Forex {
    /// Returns all forex markets.
    ///
    /// If there are no forex markets in the database yet, an empty array will be returned.
    public func getAll() -> AnyPublisher<[Database.Market.Forex],IG.Error> {
        self._database.publisher { _ in "SELECT * FROM \(Database.Market.Forex.tableName)" }
            .read { (sqlite, statement, query, _) in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
                
                var result: [Database.Market.Forex] = .init()
                while true {
                    switch sqlite3_step(statement).result {
                    case .row:  result.append(Database.Market.Forex(statement: statement!))
                    case .done: return result
                    case let e: throw IG.Error._queryFailed(code: e)
                    }
                }
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Discrete publisher returning the markets stored in the database matching the given epics.
    ///
    /// Depending on the `expectsAll` argument, this method will return the exact number of market forex or a subset of them.
    /// - parameter epics: The forex market epics identifiers.
    /// - parameter expectsAll: Boolean indicating whether an error should be emitted if not all markets are in the database.
    public func get(epics: Set<IG.Market.Epic>, expectsAll: Bool) -> AnyPublisher<Set<Database.Market.Forex>,IG.Error> {
        self._database.publisher { _ -> String in
                let values = (1...epics.count).map { "?\($0)" }.joined(separator: ", ")
                return "SELECT * FROM \(Database.Market.Forex.tableName) WHERE epic IN (\(values))"
            }.read { (sqlite, statement, query, _) in
                var result: Set<Database.Market.Forex> = .init()
                guard !epics.isEmpty else { return result }
                
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
                
                for (index, epic) in epics.enumerated() {
                    try sqlite3_bind_text(statement, Int32(index + 1), epic.description, -1, SQLite.Destructor.transient).expects(.ok) { IG.Error._bindingFailed(code: $0) }
                }
                
                loop: while true {
                    switch sqlite3_step(statement).result {
                    case .row: result.insert(.init(statement: statement!))
                    case .done: break loop
                    case let e: throw IG.Error._queryFailed(code: e)
                    }
                }
                
                guard (epics.count == result.count) || !expectsAll else {
                    throw IG.Error._notEnough(epics: epics, numResult: result.count)
                }
                return result
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Returns the market stored in the database matching the given epic.
    ///
    /// If the market is not in the database, a `.invalidResponse` error will be returned.
    /// - parameter epic: The forex market epic identifier.
    public func get(epic: IG.Market.Epic) -> AnyPublisher<Database.Market.Forex,IG.Error> {
        self._database.publisher { _ in "SELECT * FROM \(Database.Market.Forex.tableName) WHERE epic=?1" }
            .read { (sqlite, statement, query, _) in
                try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }

                try sqlite3_bind_text(statement, 1, epic.description, -1, SQLite.Destructor.transient).expects(.ok) { IG.Error._bindingFailed(code: $0) }

                switch sqlite3_step(statement).result {
                case .row: return .init(statement: statement!)
                case .done: throw IG.Error._unfoundRequestValue()
                case let e: throw IG.Error._queryFailed(code: e)
                }
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Returns the forex markets matching the given currency.
    /// - parameter currency: A currency used as base or counter in the result markets.
    /// - parameter otherCurrency: A currency matching the first argument. It is optional.
    public func get(currency: Currency.Code, _ otherCurrency: Currency.Code? = nil) -> AnyPublisher<[Database.Market.Forex],IG.Error> {
        self._database.publisher { _ -> (query: String, binds: [(index: Int32, text: Currency.Code)]) in
                var sql = "SELECT * FROM \(Database.Market.Forex.tableName) WHERE "
            
                var binds: [(index: Int32, text: Currency.Code)] = [(1, currency)]
                switch otherCurrency {
                case .none:  sql.append("base=?1 OR counter=?1")
                case let c?: sql.append("(base=?1 AND counter=?2) OR (base=?2 AND counter=?1)")
                    binds.append((2, c))
                }
            
                return (sql, binds)
            }.read { (sqlite, statement, input, _) in
                try sqlite3_prepare_v2(sqlite, input.query, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
                
                for (index, currency) in input.binds {
                    sqlite3_bind_text(statement, index, currency.description, -1, SQLite.Destructor.transient)
                }
                
                var result: [Database.Market.Forex] = .init()
                while true {
                    switch sqlite3_step(statement).result {
                    case .row:  result.append(.init(statement: statement!))
                    case .done: return result
                    case let e: throw IG.Error._queryFailed(code: e)
                    }
                }
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Returns the forex markets in the database matching the given currencies.
    ///
    /// If there are no forex markets matching the given requirements, an empty array will be returned.
    /// - parameter base: The base currency code (or `nil` if this requirement is not needed).
    /// - parameter counter: The counter currency code (or `nil` if this requirement is not needed).
    public func get(base: Currency.Code?, counter: Currency.Code?) -> AnyPublisher<[Database.Market.Forex],IG.Error> {
        guard base != nil || counter != nil else { return self.getAll() }
        
        return self._database.publisher { _ -> (query: String, binds: [(index: Int32, text: Currency.Code)]) in
            var sql = "SELECT * FROM \(Database.Market.Forex.tableName) WHERE "
            
            let binds: [(index: Int32, text: Currency.Code)]
            switch (base, counter) {
            case (let b?, .none):  sql.append("base=?1");    binds = [(1, b)]
            case (.none,  let c?): sql.append("counter=?2"); binds = [(2, c)]
            case (let b?, let c?): sql.append("base=?1 AND counter=?2"); binds = [(1, b), (2, c)]
            case (.none,  .none):  fatalError()
            }
            
            return (sql, binds)
        }.read { (sql, statement, input, _) in
            for (index, currency) in input.binds {
                sqlite3_bind_text(statement, index, currency.description, -1, SQLite.Destructor.transient)
            }
            
            var result: [Database.Market.Forex] = .init()
            while true {
                switch sqlite3_step(statement).result {
                case .row:  result.append(.init(statement: statement!))
                case .done: return result
                case let e: throw IG.Error._queryFailed(code: e)
                }
            }
        }.mapError(errorCast)
        .eraseToAnyPublisher()
    }

    /// Updates the database with the information received from the server.
    /// - note: This method is intended to be called from the update of generic markets. That is why, no transaction is performed here, since the parent method will wrap everything in its own transaction.
    /// - precondition: The market must be of currency type or an error will be returned.
    /// - parameter markets: The currency markets to be updated.
    /// - parameter sqlite: SQLite pointer priviledge access.
    internal static func update(markets: [API.Market], sqlite: SQLite.Database) throws {
        var statement: SQLite.Statement? = nil
        defer { sqlite3_finalize(statement) }
        
        let query = """
            INSERT INTO \(Database.Market.Forex.tableName) VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22, ?23)
                ON CONFLICT(epic) DO UPDATE SET base=excluded.base, counter=excluded.counter,
                    name=excluded.name, marketId=excluded.marketId, chartId=excluded.chartId, reutersId=excluded.reutersId,
                    contSize=excluded.contSize, pipVal=excluded.pipVal, placePip=excluded.placePip, placeLevel=excluded.placeLevel, slippage=excluded.slippage, premium=excluded.premium, extra=excluded.extra, margin=excluded.margin, bands=excluded.bands,
                    minSize=excluded.minSize, minDista=excluded.minDista, maxDista=excluded.maxDista, minRisk=excluded.minRisk, riskUnit=excluded.riskUnit, trailing=excluded.trailing, minStep=excluded.minStep
            """
        try sqlite3_prepare_v2(sqlite, query, -1, &statement, nil).expects(.ok) { IG.Error._compilationFailed(code: $0) }
        
        typealias F = Database.Market.Forex
        typealias D = Database.Market.Forex.DealingInformation
        typealias R = Database.Market.Forex.Restrictions
        
        for m in markets {
            guard case .success(let inferred) = Database.Market.Forex._inferred(from: m) else { continue }
            // The pip value can also be inferred from: `instrument.pip.value`
            let forex = F(epic: m.instrument.epic,
                          currencies: F.Currencies(base: inferred.base, counter: inferred.counter),
                          identifiers: F.Identifiers(name: m.instrument.name, market: inferred.marketId, chart: m.instrument.chartCode, reuters: m.instrument.newsCode),
                          information: D(contractSize: Int(clamping: inferred.contractSize),
                                         pip: D.Pip(value: Int(clamping: m.instrument.lotSize), decimalPlaces: Int(log10(Double(m.snapshot.scalingFactor)))),
                                         levelDecimalPlaces: m.snapshot.decimalPlacesFactor,
                                         slippageFactor: m.instrument.slippageFactor.value,
                                         guaranteedStop: D.GuaranteedStop(premium: m.instrument.limitedRiskPremium.value, extraSpread: m.snapshot.extraSpreadForControlledRisk),
                                         margin: D.Margin(factor: m.instrument.margin.factor, depositBands: inferred.bands)),
                          restrictions: R(minimumDealSize: m.rules.minimumDealSize.value,
                                          regularDistance: R.Distance.Regular(minimum: m.rules.limit.mininumDistance.value, maximumAsPercentage: m.rules.limit.maximumDistance.value),
                                          guarantedStopDistance: R.Distance.Variable(minimumValue: m.rules.stop.minimumLimitedRiskDistance.value, minimumUnit: inferred.guaranteedStopUnit, maximumAsPercentage: m.rules.limit.maximumDistance.value),
                                          trailingStop: R.TrailingStop(isAvailable: m.rules.stop.trailing.areAvailable, minimumIncrement: m.rules.stop.trailing.minimumIncrement.value)))
            forex._bind(to: statement!)
            try sqlite3_step(statement).expects(.done) { IG.Error._storingFailed(code: $0) }
            sqlite3_clear_bindings(statement)
            sqlite3_reset(statement)
        }
    }
}

private extension IG.Error {
    /// Error raised when a SQLite command couldn't be compiled.
    static func _compilationFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "An error occurred trying to compile a SQL statement.", info: ["Error code": code])
    }
    /// Error raised when a SQLite binding couldn't take place.
    static func _bindingFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "An error occurred binding attributes to a SQL statement.", info: ["Error code": code])
    }
    /// Error raised when a SQLite table fails.
    static func _queryFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "An error occurred querying the SQLite table.", info: ["Table": Database.Market.Forex.self, "Error code": code])
    }
    /// Error raised when a request value isn't found.
    static func _unfoundRequestValue() -> Self {
        Self(.database(.invalidResponse), "The requested value couldn't be found.", help: "The value is not in the database. Please introduce it, before trying to query it.")
    }
    /// Error raised when not enough epics have been found.
    static func _notEnough(epics: Set<IG.Market.Epic>, numResult: Int) -> Self {
        Self(.database(.invalidResponse), "The requested value couldn't be found.", help: "\(epics.count) epics were provided, however only \(numResult) epics were found.", info: ["Epics": epics])
    }
    /// Error raised when storing fails.
    static func _storingFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "An error occurred storing values on '\(Database.Market.Forex.self)'.", info: ["Error code": code])
    }
}
