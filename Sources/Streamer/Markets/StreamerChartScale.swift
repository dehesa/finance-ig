import ReactiveSwift
import Foundation

extension Streamer {
    /// Subscribes to a given market and returns aggreagated chart data.
    /// - parameter epic: The epic identifying the targeted market.
    /// - parameter interval: The aggregation interval for the candle.
    /// - parameter fields: The chart properties/fields bieng targeted.
    /// - parameter autoconnect: Boolean indicating whether the streamer connects automatically or whether it should wait for the user to explicitly call `connect()`.
    /// - returns: Signal producer that can be started at any time; when which a subscription to the server will be executed.
    public func subscribe(market epic: Epic, aggregation interval: Request.Chart.Interval, fields: Set<Request.Chart.Candle>, autoconnect: Bool = true) -> SignalProducer<Response.Chart.Candle,Streamer.Error> {
        return self.subscriptionProducer({ (streamer) -> (String, StreamerSubscriptionSession) in
            let label = streamer.queue.label + ".chart.candle.\(interval.rawValue).\(epic.identifier)"
            
            let itemName = Request.Chart.Candle.itemName(epic: epic, interval: interval)
            let subscriptionSession = streamer.session.makeSubscriptionSession(mode: .merge, items: [itemName], fields: fields)
            
            return (label, subscriptionSession)
        }, autoconnect: autoconnect) { (input, event) in
            switch event {
            case .updateReceived(let update):
                do {
                    let response = try Response.Chart.Candle(update: update)
                    input.send(value: response)
                } catch let error {
                    input.send(error: error as! Streamer.Error)
                }
            case .unsubscribed:
                input.sendCompleted()
            case .subscriptionFailed(let underlyingError):
                let itemName = Request.Chart.Candle.itemName(epic: epic, interval: interval)
                let fields = fields.map { $0.rawValue }
                input.send(error: .subscriptionFailed(to: itemName, fields: fields, error: underlyingError))
            case .subscriptionSucceeded, .updateLost(_, _):
                break
            }
        }
    }
    
    /// Subscribes to the given markets and returns aggregated chart data.
    /// - parameter epics: The epics identifying the targeted markets.
    /// - parameter interval: The aggregation interval for the candle.
    /// - parameter fields: The chart properties/fields bieng targeted.
    /// - parameter autoconnect: Boolean indicating whether the streamer connects automatically or whether it should wait for the user to explicitly call `connect()`.
    /// - returns: Signal producer that can be started at any time; when which a subscription to the server will be executed.
    public func subscribe(markets epics: [Epic], aggregation interval: Request.Chart.Interval, fields: Set<Request.Chart.Candle>, autoconnect: Bool = true) -> SignalProducer<(Epic,Response.Chart.Candle),Streamer.Error> {
        return self.subscriptionProducer({ (streamer) -> (String, StreamerSubscriptionSession) in
            guard epics.isUniquelyLaden else {
                throw Streamer.Error.invalidRequest(message: "You need to subscribe to at least one market.")
            }
            
            let suffix = epics.map { $0.identifier }.joined(separator: "|")
            let label = streamer.queue.label + ".charts.candle.\(suffix)"
            
            let itemNames = epics.map { Request.Chart.Candle.itemName(epic: $0, interval: interval) }
            let subscriptionSession = streamer.session.makeSubscriptionSession(mode: .merge, items: Set(itemNames), fields: fields)
            
            return (label, subscriptionSession)
        }, autoconnect: autoconnect) { (input, event) in
            switch event {
            case .updateReceived(let update):
                do {
                    guard let epic = Request.Chart.Candle.epic(itemName: update.item, interval: interval, requestedEpics: epics) else {
                        throw Streamer.Error.invalidResponse(item: update.item, fields: update.all, message: "The item name couldn't be identified.")
                    }
                    let response = try Response.Chart.Candle(update: update)
                    input.send(value: (epic, response))
                } catch let error {
                    input.send(error: error as! Streamer.Error)
                }
            case .unsubscribed:
                input.sendCompleted()
            case .subscriptionFailed(let underlyingError):
                let items = epics.map { Request.Chart.Tick.itemName(epic: $0) }.joined(separator: ", ")
                let fields = fields.map { $0.rawValue }
                input.send(error: .subscriptionFailed(to: items, fields: fields, error: underlyingError))
            case .subscriptionSucceeded, .updateLost(_, _):
                break
            }
        }
    }
}

extension Streamer.Request.Chart {
    /// The time interval used for aggregation.
    public enum Interval: String {
        case second = "SECOND"
        case minute = "1MINUTE"
        case fiveMinutes = "5MINUTE"
        case hour = "HOUR"
    }
    
    /// Possible fields to subscribe to when querying market candle data.
    public enum Candle: String, StreamerFieldKeyable, CaseIterable {
        /// Update time.
        case date = "UTM"
        /// Whether the candle has ended (1 ends, 0 continues).
        case isFinished = "CONS_END"
        /// Number of ticks in candle.
        case numTicks = "CONS_TICK_COUNT"
        /// Candle bid open price.
        case bidOpen = "BID_OPEN"
        /// Candle bid low price.
        case bidLow = "BID_LOW"
        /// Candle bid high price.
        case bidHigh = "BID_HIGH"
        /// Candle bid close price.
        case bidClose = "BID_CLOSE"
        /// Candle offer open price.
        case offerOpen = "OFR_OPEN"
        /// Candle offer low price.
        case offerLow = "OFR_LOW"
        /// Candle offer high price.
        case offerHigh = "OFR_HIGH"
        /// Candle offer close price.
        case offerClose = "OFR_CLOSE"
        // /// Candle open price (Last Traded Price)
        // case lastTradedPriceOpen = "LTP_OPEN"
        // /// Candle low price (Last Traded Price)
        // case lastTradedPriceLow = "LTP_LOW"
        // /// Candle high price (Last Traded Price)
        // case lastTradedPriceHigh = "LTP_HIGH"
        // /// Candle close price (Last Traded Price)
        // case lastTradedPriceClose = "LTP_CLOSE"
        /// Last traded volume.
        case lastTradedVolume = "LTV"
        // /// Incremental trading volume.
        // case incrementalTradingVolume = "TTV"
        /// Daily low price.
        case low = "DAY_LOW"
        /// Mid open price for the day.
        case midOpen = "DAY_OPEN_MID"
        /// Daily high price.
        case high = "DAY_HIGH"
        /// Change from open price to current.
        case changeNet = "DAY_NET_CHG_MID"
        /// Daily percentage change.
        case changePercentage = "DAY_PERC_CHG_MID"
        
        private static var prefix: String {
            return "CHART:"
        }
        
        fileprivate static func itemName(epic: Epic, interval: Streamer.Request.Chart.Interval) -> String {
            return self.prefix + epic.identifier + ":" + interval.rawValue
        }
        
        fileprivate static func epic(itemName: String, interval: Streamer.Request.Chart.Interval, requestedEpics epics: [Epic]) -> Epic? {
            let postfix = ":" + interval.rawValue
            guard itemName.hasPrefix(self.prefix), itemName.hasSuffix(postfix) else { return nil }
            let identifier = String(itemName.dropLast(postfix.count).dropFirst(self.prefix.count))
            return epics.find { $0.identifier == identifier }
        }
        
        public var keyPath: PartialKeyPath<Streamer.Response.Chart.Candle> {
            switch self {
            case .date:             return \Response.date
            case .isFinished:       return \Response.isFinished
            case .numTicks:         return \Response.numTicks
            case .bidOpen:          return \Response.price.bid.open
            case .bidClose:         return \Response.price.bid.close
            case .bidLow:           return \Response.price.bid.low
            case .bidHigh:          return \Response.price.bid.high
            case .offerOpen:        return \Response.price.offer.open
            case .offerClose:       return \Response.price.offer.close
            case .offerLow:         return \Response.price.offer.low
            case .offerHigh:        return \Response.price.offer.high
            // case .lastTradedPriceOpen:  return \Response.price.lastTraded.open
            // case .lastTradedPriceClose: return \Response.price.lastTraded.close
            // case .lastTradedPriceLow:   return \Response.price.lastTraded.low
            // case .lastTradedPriceHigh:  return \Response.price.lastTraded.high
            case .lastTradedVolume: return \Response.volume.lastTraded
            // case .incrementalTradingVolume: return \Response.volume.incremental
            case .low:              return \Response.intraday.low
            case .midOpen:          return \Response.intraday.midOpen
            case .high:             return \Response.intraday.high
            case .changeNet:        return \Response.intraday.change.net
            case .changePercentage: return \Response.intraday.change.percentage
            }
        }
    }
}

extension Streamer.Response.Chart {
    /// Response for a Market chart aggregated stream package.
    public struct Candle: StreamerResponse, StreamerUpdatable {
        public typealias Field = Streamer.Request.Chart.Candle
        public let fields: Candle.Update
        /// The date of the information.
        public let date: Date?
        /// Boolean indicating whether no further values will be added to this candle.
        public let isFinished: Bool?
        /// Number of ticks in the candle.
        public let numTicks: Int?
        /// Price related information (e.g. buy, sell price, etc.)
        public let price: Price
        /// Traded volume information.
        public let volume: Volume
        /// Highest and lowest price of the day.
        public let intraday: Intraday
        
        internal init(update: StreamerSubscriptionUpdate) throws {
            let (values, fields) = try Update.make(update)
            self.fields = fields
            
            self.date = values[.date].flatMap {
                guard let milliseconds = TimeInterval($0) else { return nil }
                return Date(timeIntervalSince1970: milliseconds / 1000)
            }
            self.isFinished = values[.isFinished].flatMap {
                guard let number = Int($0) else { return nil }
                return number != 0
            }
            self.numTicks = values[.numTicks].flatMap { Int($0) }
            self.price = Price(received: values)
            self.volume = Volume(received: values)
            self.intraday = Intraday(received: values)
        }
    }
}

extension Streamer.Response.Chart.Candle {
    /// Buy/Sell prices at a point in time.
    public struct Price {
        /// Buy price.
        public let offer: Range
        /// Sell price.
        public let bid: Range
        // /// Last traded price.
        // public let lastTraded: Properties
        
        fileprivate init(received: [Field:String]) {
            self.offer = Range(received: received, fields: (.offerOpen, .offerClose, .offerLow, .offerHigh))
            self.bid = Range(received: received, fields: (.bidOpen, .bidClose, .bidLow, .bidHigh))
            // self.lastTraded = Properties(received: received, fields: (.lastTradedPriceOpen, .lastTradedPriceClose, .lastTradedPriceLow, .lastTradedPriceHigh))
        }
    }
    
    /// Trading volume related information.
    public struct Volume {
        /// Last traded volume.
        public let lastTraded: Double?
        // /// Incremental trading volume.
        // public let incremental: Double?
        
        fileprivate init(received: [Field:String]) {
            self.lastTraded = received[.lastTradedVolume].flatMap { Double($0) }
            // self.incremental = received[.incrementalTradingVolume].flatMap { Double($0) }
        }
    }
    
    /// The price range.
    public struct Intraday {
        /// Intraday lowest price.
        public let low: Double?
        /// Opening mid price.
        public let midOpen: Double?
        /// Intraday highest price.
        public let high: Double?
        /// Price change net and percentage change on that day.
        public let change: Change
        
        fileprivate init(received: [Field:String]) {
            self.low = received[.low].flatMap { Double($0) }
            self.midOpen = received[.midOpen].flatMap { Double($0) }
            self.high = received[.high].flatMap { Double($0) }
            self.change = Change(received: received)
        }
    }
}

extension Streamer.Response.Chart.Candle {
    /// Price candle properties.
    public struct Range {
        /// The open price for a given candle.
        public let open: Double?
        /// The close price for a given candle.
        public let close: Double?
        /// The lowest price reached on a candle.
        public let low: Double?
        /// The highest price reached on a candle.
        public let high: Double?
        
        fileprivate init(received: [Field:String], fields: (open: Field, close: Field, low: Field, high: Field)) {
            self.open = received[fields.open].flatMap { Double($0) }
            self.close = received[fields.close].flatMap { Double($0) }
            self.low = received[fields.low].flatMap { Double($0) }
            self.high = received[fields.high].flatMap { Double($0) }
        }
    }

    /// The change in price.
    public struct Change {
        /// Change from open price to current.
        public let net: Double?
        /// Daily percentage change.
        public let percentage: Double?
        
        fileprivate init(received: [Field:String]) {
            self.net = received[.changeNet].flatMap { Double($0) }
            self.percentage = received[.changePercentage].flatMap { Double($0) }
        }
    }
}
