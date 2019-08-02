import ReactiveSwift
import Foundation

extension Streamer.Request.Markets {
    
    // MARK: MARKET:EPIC
    
    /// Subscribes to the given market and returns in the response the specified attributes/fields.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter epic: The epic identifying the targeted market.
    /// - parameter fields: The market properties/fields bieng targeted.
    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market.
    public func subscribe(to epic: Epic, _ fields: Set<Streamer.Market.Field>, snapshot: Bool = true) -> SignalProducer<Streamer.Market,Streamer.Error> {
        let item = "MARKET:\(epic.rawValue)"
        let properties = fields.map { $0.rawValue }
        let timeFormatter = Streamer.Formatter.time
        
        return self.streamer.channel
            .subscribe(mode: .merge, item: item, fields: properties, snapshot: snapshot)
            .attemptMap { (update) in
                do {
                    let market = try Streamer.Market(epic: epic, item: item, update: update, timeFormatter: timeFormatter)
                    return .success(market)
                } catch let error as Streamer.Error {
                    return .failure(error)
                } catch let error {
                    return .failure(.invalidResponse(item: item, fields: update, message: "An unkwnon error occur will parsing a market update.\nError: \(error)"))
                }
            }
    }
    
//    /// Subscribes to the given sprint market and returns in the response the specified attributes/fields.
//    ///
//    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
//    /// - parameter epic: The epic identifying the targeted market.
//    /// - parameter fields: The market properties/fields bieng targeted.
//    /// - parameter snapshot: Boolean indicating whether a "beginning" package should be sent with the current state of the market.
//    public func subscribeSprint(to epic: Epic, _ fields: Set<Streamer.SprintMarket.Field>, snapshot: Bool = true) -> SignalProducer<Streamer.SprintMarket,Streamer.Error> {
//        let item = "MARKET:\(epic.rawValue)"
//        let properties = fields.map { $0.rawValue }
//        
//        return self.streamer.channel
//            .subscribe(mode: .merge, item: item, fields: properties, snapshot: snapshot)
//            .attemptMap { (update) in
//                do {
//                    let market = try Streamer.SprintMarket(epic: epic, item: item, update: update)
//                    return .success(market)
//                } catch let error as Streamer.Error {
//                    return .failure(error)
//                } catch let error {
//                    return .failure(.invalidResponse(item: item, fields: update, message: "An unkwnon error occur will parsing a market update.\nError: \(error)"))
//                }
//        }
//    }
}

// MARK: - Supporting Entities

extension Streamer.Request {
    /// Contains all functionality related to Streamer markets.
    public struct Markets {
        /// Pointer to the actual Streamer instance in charge of calling the Lightstreamer server.
        internal unowned let streamer: Streamer
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter streamer: The instance calling the actual subscriptions.
        init(streamer: Streamer) {
            self.streamer = streamer
        }
    }
}

// MARK: Request Entities

extension Streamer.Market {
    /// All available fields/properties to query data from a given market.
    public enum Field: String, CaseIterable {
        /// The current market status.
        case status = "MARKET_STATE"
        /// Publis time of last price update.
        case date = "UPDATE_TIME"
        /// Boolean indicating whether prices are delayed.
        case isDelayed = "MARKET_DELAY"
        
        /// The bid price.
        case bid = "BID"
        /// The offer price.
        case ask = "OFFER"
        
        /// Intraday high price.
        case high = "HIGH"
        /// Opening mid price.
        case mid = "MID_OPEN"
        /// Intraday low price.
        case low = "LOW"
        /// Price change compared with open value.
        case changeNet = "CHANGE"
        /// Price percent change compared with open value.
        case changePercentage = "CHANGE_PCT"
    }
}

//extension Streamer.SprintMarket {
//    /// All available fields/properties to query data from a given sprint market.
//    public enum Field: String, CaseIterable {
//        case status = "MARKET_STATE"
//        case strikePrice = "STRIKE_PRICE"
//        case odds = "ODDS"
//    }
//}

// MARK: Response Entities

extension Streamer {
    /// Displays the latests information from a given market.
    public struct Market {
        /// The market epic identifier.
        public let epic: Epic
        /// The current market status.
        public let status: Self.Status?
        
        /// Publis time of last price update.
        public let date: Date?
        /// Boolean indicating whether prices are delayed.
        public let isDelayed: Bool?
        
        /// The bid price.
        public let bid: Decimal?
        /// The offer price.
        public let ask: Decimal?
        
        /// Intraday high price.
        public let high: Decimal?
        /// Opening mid price.
        public let mid: Decimal?
        /// Intraday low price.
        public let low: Decimal?
        /// Price change compared with open value.
        public let changeNet: Decimal?
        /// Price percent change compared with open value.
        public let changePercentage: Decimal?
        
        /// Designated initializer for a `Streamer` market update.
        fileprivate init(epic: Epic, item: String, update: [String:String], timeFormatter: DateFormatter) throws {
            typealias F = Self.Field
            typealias U = Streamer.Formatter.Update
            
            self.epic = epic
            
            do {
                self.status = try update[F.status.rawValue].map(U.toRawType)
                self.date = try update[F.date.rawValue].map { try U.toTime($0, timeFormatter: timeFormatter) }
                self.isDelayed = try update[F.isDelayed.rawValue].map(U.toBoolean)
                
                self.bid = try update[F.bid.rawValue].map(U.toDecimal)
                self.ask = try update[F.ask.rawValue].map(U.toDecimal)
                
                self.high = try update[F.high.rawValue].map(U.toDecimal)
                self.mid = try update[F.mid.rawValue].map(U.toDecimal)
                self.low = try update[F.low.rawValue].map(U.toDecimal)
                self.changeNet = try update[F.changeNet.rawValue].map(U.toDecimal)
                self.changePercentage = try update[F.changePercentage.rawValue].map(U.toDecimal)
            } catch let error as U.Error {
                throw Streamer.Error.invalidResponse(item: item, fields: update, message: "An error was encountered when parsing the value \"\(error.value)\" from a \"String\" to a \"\(error.type)\".")
            } catch let error {
                throw Streamer.Error.invalidResponse(item: item, fields: update, message: "An unknown error was encountered when parsing the updated payload.\nError: \(error)")
            }
        }
    }
}

extension Streamer.Market: CustomDebugStringConvertible {
    /// The current status of the market.
    public enum Status: String, Codable {
        /// The market is open for trading.
        case tradeable = "TRADEABLE"
        /// The market is closed for the moment. Look at the market's opening hours for further information.
        case closed = "CLOSED"
        case editsOnly = "EDIT"
        case onAuction = "AUCTION"
        case onAuctionNoEdits = "AUCTION_NO_EDIT"
        case offline = "OFFLINE"
        /// The market is suspended for trading temporarily.
        case suspended = "SUSPENDED"
    }

    public var debugDescription: String {
        var result: String = self.epic.rawValue
        result.append(prefix: "\n\t", name: "Status", ": ", value: self.status)
        result.append(prefix: "\n\t", name: "Date", ": ", value: self.date.map { Streamer.Formatter.time.string(from: $0) })
        result.append(prefix: "\n\t", name: "Are prices delayed?", " ", value: self.isDelayed)
        result.append(prefix: "\n\t", name: "Price (bid)", ": ", value: self.bid)
        result.append(prefix: "\n\t", name: "Price (ask)", ": ", value: self.ask)
        result.append(prefix: "\n\t", name: "Range (high)", ": ", value: self.high)
        result.append(prefix: "\n\t", name: "Range (mid)", ": ", value: self.mid)
        result.append(prefix: "\n\t", name: "Range (low)", ": ", value: self.low)
        result.append(prefix: "\n\t", name: "Change (net)", ": ", value: self.changeNet)
        result.append(prefix: "\n\t", name: "Change (%)", ": ", value: self.changePercentage)
        return result
    }
}

//extension Streamer {
//    /// Displays the latests information from a given market.
//    public struct SprintMarket: CustomDebugStringConvertible {
//        /// The market epic identifier.
//        public let epic: Epic
//        /// The current market status.
//        public let status: Streamer.Market.Status?
//        /// (Sprint markets) Strike price.
//        public let strikePrice: Decimal?
//        /// (Sprint markets) Trade odds.
//        public let odds: String?
//
//        /// Designated initializer for a `Streamer` market update.
//        fileprivate init(epic: Epic, item: String, update: [String:String]) throws {
//            typealias F = Self.Field
//            typealias U = Streamer.Formatter.Update
//
//            self.epic = epic
//            self.odds = update[F.odds.rawValue]
//
//            do {
//                self.status = try update[F.status.rawValue].map(U.toRawType)
//                self.strikePrice = try update[F.strikePrice.rawValue].map(U.toDecimal)
//            } catch let error as U.Error {
//                throw Streamer.Error.invalidResponse(item: item, fields: update, message: "An error was encountered when parsing the value \"\(error.value)\" from a \"String\" to a \"\(error.type)\".")
//            } catch let error {
//                throw Streamer.Error.invalidResponse(item: item, fields: update, message: "An unknown error was encountered when parsing the updated payload.\nError: \(error)")
//            }
//        }
//
//        public var debugDescription: String {
//            var result: String = self.epic.rawValue
//            result.append(prefix: "\n\t", name: "Status", ": ", value: self.status)
//            result.append(prefix: "\n\t", name: "Sprint markets (strike)", ": ", value: self.strikePrice)
//            result.append(prefix: "\n\t", name: "Sprint markets (odds)", ": ", value: self.odds)
//            return result
//        }
//    }
//}
