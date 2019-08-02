import ReactiveSwift
import Foundation

extension Streamer.Request.Markets {
    
    // MARK: CHART:EPIC:TICK
    
//    /// Subscribes to a given market and returns every tick data.
//    /// - parameter epic: The epic identifying the targeted market.
//    /// - parameter fields: The chart properties/fields bieng targeted.
//    /// - parameter autoconnect: Boolean indicating whether the streamer connects automatically or whether it should wait for the user to explicitly call `connect()`.
//    /// - returns: Signal producer that can be started at any time; when which a subscription to the server will be executed.
//    public func subscribe(chart epic: Epic, fields: Set<Request.Chart.Tick>, autoconnect: Bool = true) -> SignalProducer<Response.Chart.Tick,Streamer.Error> {
//        return self.subscriptionProducer({ (streamer) -> (String, StreamerSubscriptionSession) in
//            let label = streamer.queue.label + ".chart.tick." + epic.identifier
//            
//            let itemName = Request.Chart.Tick.itemName(epic: epic)
//            let subscriptionSession = streamer.session.makeSubscriptionSession(mode: .distinct, items: [itemName], fields: fields)
//            
//            return (label, subscriptionSession)
//        }, autoconnect: autoconnect) { (input, event) in
//            switch event {
//            case .updateReceived(let update):
//                do {
//                    let response = try Response.Chart.Tick(update: update)
//                    input.send(value: response)
//                } catch let error {
//                    input.send(error: error as! Streamer.Error)
//                }
//            case .unsubscribed:
//                input.sendCompleted()
//            case .subscriptionFailed(let underlyingError):
//                let itemName = Request.Chart.Tick.itemName(epic: epic)
//                let fields = fields.map { $0.rawValue }
//                input.send(error: .subscriptionFailed(to: itemName, fields: fields, error: underlyingError))
//            case .subscriptionSucceeded, .updateLost(_, _):
//                break
//            }
//        }
//    }
}

// MARK: - Supporting Entities

// MARK: Request Entities

//extension Streamer.Request.Chart {
//    /// Possible fields to subscribe to when querying the tick chart.
//    public enum Tick: String, StreamerFieldKeyable, CaseIterable, StreamerRequestItemNamePrePostFixable, StreamerRequestItemNameEpicable {
//        /// Update time.
//        case date = "UTM"
//        /// Bid price
//        case bid = "BID"
//        /// Offer price.
//        case offer = "OFR"
//        // /// Last traded price.
//        // case lastTradedPrice = "LTP"
//        /// Last traded volume.
//        case lastTradedVolume = "LTV"
//        // /// Incremental trading volume.
//        // case incrementalTradingVolume = "TTV"
//        /// Daily low price.
//        case low = "DAY_LOW"
//        /// Mid open price for the day.
//        case midOpen = "DAY_OPEN_MID"
//        /// Daily high price.
//        case high = "DAY_HIGH"
//        /// Change from open price to current.
//        case changeNet = "DAY_NET_CHG_MID"
//        /// Daily percentage change.
//        case changePercentage = "DAY_PERC_CHG_MID"
//        
//        internal static var prefix: String {
//            return "CHART:"
//        }
//        
//        internal static var postfix: String {
//            return ":TICK"
//        }
//        
//        public var keyPath: PartialKeyPath<Streamer.Response.Chart.Tick> {
//            switch self {
//            case .date:             return \Response.date
//            case .bid:              return \Response.price.bid
//            case .offer:            return \Response.price.offer
//            // case .lastTradedPrice:  return \Response.price.lastTraded
//            case .lastTradedVolume: return \Response.volume.lastTraded
//            // case .incrementalTradingVolume: return \Response.volume.incremental
//            case .low:              return \Response.intraday.low
//            case .midOpen:          return \Response.intraday.midOpen
//            case .high:             return \Response.intraday.high
//            case .changeNet:        return \Response.intraday.change.net
//            case .changePercentage: return \Response.intraday.change.percentage
//            }
//        }
//    }
//}
//
//extension Streamer.Response.Chart {
//    /// Response for a Market chart tick stream package.
//    public struct Tick: StreamerResponse, StreamerUpdatable {
//        public typealias Field = Streamer.Request.Chart.Tick
//        public let fields: Tick.Update
//        /// The date of the information.
//        public let date: Date?
//        /// Price related information (e.g. buy, sell price, etc.)
//        public let price: Price
//        /// Traded volume information.
//        public let volume: Volume
//        /// Highest and lowest price of the day.
//        public let intraday: Intraday
//        
//        internal init(update: StreamerSubscriptionUpdate) throws {
//            let (values, fields) = try Update.make(update)
//            self.fields = fields
//            
//            self.date = values[.date].flatMap {
//                guard let milliseconds = TimeInterval($0) else { return nil }
//                return Date(timeIntervalSince1970: milliseconds / 1000)
//            }
//            self.price = Price(received: values)
//            self.volume = Volume(received: values)
//            self.intraday = Intraday(received: values)
//        }
//    }
//}
//
//extension Streamer.Response.Chart.Tick {
//    /// Buy/Sell prices at a point in time.
//    public struct Price {
//        /// Buy price.
//        public let offer: Double?
//        /// Sell price.
//        public let bid: Double?
//        // /// Last traded price.
//        // public let lastTraded: Double?
//        
//        fileprivate init(received: [Field:String]) {
//            self.offer = received[.offer].flatMap { Double($0) }
//            self.bid = received[.bid].flatMap { Double($0) }
//            // self.lastTraded = received[.lastTradedPrice].flatMap { Double($0) }
//        }
//    }
//    
//    /// Trading volume related information.
//    public struct Volume {
//        /// Last traded volume.
//        public let lastTraded: Double?
//        // /// Incremental trading volume.
//        // public let incremental: Double?
//        
//        fileprivate init(received: [Field:String]) {
//            self.lastTraded = received[.lastTradedVolume].flatMap { Double($0) }
//            // self.incremental = received[.incrementalTradingVolume].flatMap { Double($0) }
//        }
//    }
//    
//    /// The price range.
//    public struct Intraday {
//        /// Intraday lowest price.
//        public let low: Double?
//        /// Opening mid price.
//        public let midOpen: Double?
//        /// Intraday highest price.
//        public let high: Double?
//        /// Price change net and percentage change on that day.
//        public let change: Change
//        
//        fileprivate init(received: [Field:String]) {
//            self.low = received[.low].flatMap { Double($0) }
//            self.midOpen = received[.midOpen].flatMap { Double($0) }
//            self.high = received[.high].flatMap { Double($0) }
//            self.change = Change(received: received)
//        }
//    }
//}
//
//extension Streamer.Response.Chart.Tick {
//    /// The change in price.
//    public struct Change {
//        /// Change from open price to current.
//        public let net: Double?
//        /// Daily percentage change.
//        public let percentage: Double?
//        
//        fileprivate init(received: [Field:String]) {
//            self.net = received[.changeNet].flatMap { Double($0) }
//            self.percentage = received[.changePercentage].flatMap { Double($0) }
//        }
//    }
//}
