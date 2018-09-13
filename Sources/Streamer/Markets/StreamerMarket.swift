import ReactiveSwift
import Foundation

extension Streamer {
    /// Subscribes to the given market and returns in the response the specified attributes/fields.
    ///
    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
    /// - parameter epic: The epic identifying the targeted market.
    /// - parameter fields: The market properties/fields bieng targeted.
    /// - parameter autoconnect: Boolean indicating whether the streamer connects automatically or whether it should wait for the user to explicitly call `connect()`.
    /// - returns: Signal producer that can be started at any time; when which a subscription to the server will be executed.
    public func subscribe(market epic: Epic, fields: Set<Request.Market>, autoconnect: Bool = true) -> SignalProducer<Response.Market,Streamer.Error> {
        return self.subscriptionProducer({ (streamer) -> (String, StreamerSubscriptionSession) in
            let label = streamer.queue.label + ".market." + epic.identifier
            
            let itemName = Request.Market.itemName(identifier: epic.identifier)
            let subscriptionSession = streamer.session.makeSubscriptionSession(mode: .merge, items: [itemName], fields: fields)
            
            return (label, subscriptionSession)
        }, autoconnect: autoconnect) { (input, event) in
            switch event {
            case .updateReceived(let update):
                do {
                    let response = try Response.Market(update: update)
                    input.send(value: response)
                } catch let error {
                    input.send(error: error as! Streamer.Error)
                }
            case .unsubscribed:
                input.sendCompleted()
            case .subscriptionFailed(let underlyingError):
                let itemName = Request.Market.itemName(identifier: epic.identifier)
                let fields = fields.map { $0.rawValue }
                input.send(error: .subscriptionFailed(to: itemName, fields: fields, error: underlyingError))
            case .subscriptionSucceeded, .updateLost(_,_):
                break
            }
        }
    }
    
    /// Subscribes to the given markets and returns in the response the specified attributes/fields.
    /// - parameter epics: The epics identifying the targeted markets.
    /// - parameter fields: The market properties/fields bieng targeted.
    /// - parameter autoconnect: Boolean indicating whether the streamer connects automatically or whether it should wait for the user to explicitly call `connect()`.
    /// - returns: Signal producer that can be started at any time; when which a subscription to the server will be executed.
    public func subscribe(markets epics: [Epic], fields: Set<Request.Market>, autoconnect: Bool = true) -> SignalProducer<(Epic,Response.Market),Streamer.Error> {
        return self.subscriptionProducer({ (streamer) -> (String, StreamerSubscriptionSession) in
            guard epics.isUniquelyLaden else {
                throw Streamer.Error.invalidRequest(message: "You need to subscribe to at least one market.")
            }
            
            let suffix = epics.map { $0.identifier }.joined(separator: "|")
            let label = streamer.queue.label + ".markets." + suffix

            let itemNames = epics.map { Request.Market.itemName(identifier: $0.identifier) }
            let subscriptionSession = streamer.session.makeSubscriptionSession(mode: .merge, items: Set(itemNames), fields: fields)

            return (label, subscriptionSession)
        }, autoconnect: autoconnect) { (input, event) in
            switch event {
            case .updateReceived(let update):
                do {
                    guard let epic = Request.Market.epic(itemName: update.item, requestedEpics: epics) else {
                        throw Streamer.Error.invalidResponse(item: update.item, fields: update.all, message: "The item name couldn't be identified.")
                    }
                    let response = try Response.Market(update: update)
                    input.send(value: (epic, response))
                } catch let error {
                    input.send(error: error as! Streamer.Error)
                }
            case .unsubscribed:
                input.sendCompleted()
            case .subscriptionFailed(let underlyingError):
                let items = epics.map { Request.Market.itemName(identifier: $0.identifier) }.joined(separator: ", ")
                let error: Streamer.Error = .subscriptionFailed(to: items, fields: fields.map { $0.rawValue }, error: underlyingError)
                input.send(error: error)
            case .subscriptionSucceeded, .updateLost(_, _):
                break
            }
        }
    }
}

extension Streamer.Request {
    /// Possible fields to subscribe to when querying market data.
    public enum Market: String, StreamerFieldKeyable, CaseIterable, StreamerRequestItemNamePrefixable, StreamerRequestItemNameEpicable {
        /// Market status.
        case status = "MARKET_STATE"
        /// Publish time of last price update (UK local time, i.e. GMT or BST)
        case date = "UPDATE_TIME"
        /// Offer price
        case offer = "OFFER"
        /// Bid price
        case bid = "BID"
        /// Strike price
        case strike = "STRIKE_PRICE"
        /// Delayed price (0=false, 1=true)
        case isDelayed = "MARKET_DELAY"
        /// Intraday low price
        case low = "LOW"
        /// Opening mid price.
        case midOpen = "MID_OPEN"
        /// Intraday high price.
        case high = "HIGH"
        /// Price change compared with open value.
        case changeNet = "CHANGE"
        /// Price percent change compared with open value.
        case changePercentage = "CHANGE_PCT"
        
        internal static var prefix: String {
            return "MARKET:"
        }

        public var keyPath: PartialKeyPath<Streamer.Response.Market> {
            switch self {
            case .status:    return \Response.status
            case .date:      return \Response.date
            case .offer:     return \Response.price.offer
            case .bid:       return \Response.price.bid
            case .strike:    return \Response.price.strike
            case .isDelayed: return \Response.price.isDelayed
            case .low:       return \Response.range.low
            case .midOpen:   return \Response.range.midOpen
            case .high:      return \Response.range.high
            case .changeNet: return \Response.change.net
            case .changePercentage: return \Response.change.percentage
            }
        }
    }
}

extension Streamer.Response {
    /// Response for a Market stream package.
    public struct Market: StreamerResponse, StreamerUpdatable {
        public typealias Field = Streamer.Request.Market
        public let fields: Market.Update
        /// The current status of the market.
        public let status: Status?
        /// Publish time of last price update (UK local time, i.e. GMT or BST).
        public let date: Date?
        /// Offer (buy) and bid (sell) price.
        public let price: Price
        /// Highest and lowest price of the day.
        public let range: Range
        /// Price change net and percentage change on that day.
        public let change: Change

        internal init(update: StreamerSubscriptionUpdate) throws {
            let (values, fields) = try Update.make(update)
            self.fields = fields

            self.status = values[.status].flatMap { Status(rawValue: $0) }
            self.date = try values[.date].flatMap {
                let formatter = Streamer.DateFormatter.time
                guard let parsedDate = formatter.date(from: $0) else {
                    throw Streamer.Error.invalidResponse(item: update.item, fields: values, message: "The Market \"\(Field.date.rawValue)\" couldn't be parsed.")
                }

                let now = Date()
                let result = try parsedDate.mixComponents([.hour, .minute, .second], withDate: now, [.year, .month, .day], calendar: formatter.calendar, timezone: formatter.timeZone)
                    ?! Streamer.Error.invalidResponse(item: update.item, fields: values, message: "The Market \"\(Field.date.rawValue)\" was parsed \"\($0)\", but it couldn't be transformed into a date.")

                // For the general cases the `guard` statement won't be fulfilled.
                guard result > now else { return result }
                // The following transformation take care of the edge cases for dates close to midnight.
                return try formatter.calendar.date(byAdding: .day, value: -1, to: result)
                    ?! Streamer.Error.invalidResponse(item: update.item, fields: values, message: "The Market \"\(Field.date.rawValue)\" was parsed \"\($0)\", but operations couldn't be performed on it.")
            }
            self.price = Price(received: values)
            self.range = Range(received: values)
            self.change = Change(received: values)
        }
    }
}

extension Streamer.Response.Market {
    /// The state of the market.
    public enum Status: String {
        case closed = "CLOSED"
        case offline = "OFFLINE"
        case tradable = "TRADEABLE"
        case editsOnly = "EDIT"
        case onAuction = "AUCTION"
        case onAcutionNoEdits = "AUCTION_NO_EDIT"
        case suspended = "SUSPENDED"
    }

    /// Buy/Sell prices at a point in time.
    public struct Price {
        /// Buy price.
        public let offer: Double?
        /// Sell price.
        public let bid: Double?
        /// Strike price.
        public let strike: Double?
        /// Whether the price is delayed with the market.
        public let isDelayed: Bool?

        fileprivate init(received: [Field:String]) {
            self.offer = received[.offer].flatMap { Double($0) }
            self.bid = received[.bid].flatMap { Double($0) }
            self.strike = received[.bid].flatMap { Double($0) }
            self.isDelayed = received[.isDelayed].flatMap { Int($0) }.map { $0 != 0 }
        }
    }

    /// The price range (low, mid, high).
    public struct Range {
        /// Intraday low price
        public let low: Double?
        /// Opening mid price.
        public let midOpen: Double?
        /// Intraday high price.
        public let high: Double?

        fileprivate init(received: [Field:String]) {
            self.low = received[.low].flatMap { Double($0) }
            self.midOpen = received[.midOpen].flatMap { Double($0) }
            self.high = received[.high].flatMap { Double($0) }
        }
    }

    /// The change in price compared to open value.
    public struct Change {
        /// Price change compared with open value
        public let net: Double?
        /// Price percent change compared with open value
        public let percentage: Double?

        fileprivate init(received: [Field:String]) {
            self.net = received[.changeNet].flatMap { Double($0) }
            self.percentage = received[.changePercentage].flatMap { Double($0) }
        }
    }
}
