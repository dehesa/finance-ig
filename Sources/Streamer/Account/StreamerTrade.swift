//import ReactiveSwift
//import Foundation
//
//extension Streamer {
//    /// Subscribes to the given account and receives updates on positions, working orders, and trade confirmations.
//    ///
//    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
//    /// - parameter accountId: The identifying for the targeted account.
//    /// - parameter fields: The account properties/fields bieng targeted.
//    /// - parameter autoconnect: Boolean indicating whether the streamer connects automatically or whether it should wait for the user to explicitly call `connect()`.
//    /// - returns: Signal producer that can be started at any time; when which a subscription to the server will be executed.
//    public func subscribe(account accountId: String, updates fields: Set<Request.Trade>, autoconnect: Bool = true) -> SignalProducer<Response.Trade,Streamer.Error> {
//        return self.subscriptionProducer({ (streamer) -> (String, StreamerSubscriptionSession) in
//            let label = streamer.queue.label + ".trade." + accountId
//            
//            let itemName = Request.Trade.itemName(identifier: accountId)
//            let subscriptionSession = streamer.session.makeSubscriptionSession(mode: .distinct, items: [itemName], fields: fields)
//            
//            return (label, subscriptionSession)
//        }, autoconnect: autoconnect) { (input, event) in
//            switch event {
//            case .updateReceived(let update):
//                do {
//                    let response = try Response.Trade(update: update)
//                    input.send(value: response)
//                } catch let error {
//                    input.send(error: error as! Streamer.Error)
//                }
//            case .unsubscribed:
//                input.sendCompleted()
//            case .subscriptionFailed(let underlyingError):
//                let itemName = Request.Trade.itemName(identifier: accountId)
//                let fields = fields.map { $0.rawValue }
//                input.send(error: .subscriptionFailed(to: itemName, fields: fields, error: underlyingError))
//            case .subscriptionSucceeded, .updateLost(_,_):
//                break
//            }
//        }
//    }
//    
//    /// Subscribes to the given accounts and receives updates on positions, working orders, and trade confirmations.
//    ///
//    /// The only way to unsubscribe is to not hold the signal producer returned and have no active observer in the signal.
//    /// - parameter accountIds: The Account identifiers.
//    /// - parameter fields: The account properties/fields bieng targeted.
//    /// - parameter autoconnect: Boolean indicating whether the streamer connects automatically or whether it should wait for the user to explicitly call `connect()`.
//    /// - returns: Signal producer that can be started at any time; when which a subscription to the server will be executed.
//    public func subscribe(accounts accountIds: [String], updates fields: Set<Request.Trade>, autoconnect: Bool = true) -> SignalProducer<(String,Response.Trade),Streamer.Error> {
//        return self.subscriptionProducer({ (streamer) -> (String, StreamerSubscriptionSession) in
//            guard accountIds.isUniquelyLaden else {
//                throw Streamer.Error.invalidRequest(message: "You need to subscribe to at least one account.")
//            }
//            
//            let suffix = accountIds.joined(separator: "|")
//            let label = streamer.queue.label + ".trade." + suffix
//            
//            let itemNames = accountIds.map { Request.Trade.itemName(identifier: $0) }
//            let subscriptionSession = streamer.session.makeSubscriptionSession(mode: .distinct, items: Set(itemNames), fields: fields)
//            
//            return (label, subscriptionSession)
//        }, autoconnect: autoconnect) { (input, event) in
//            switch event {
//            case .updateReceived(let update):
//                do {
//                    guard let accountId = Request.Trade.accountId(itemName: update.item, requestedAccounts: accountIds) else {
//                        throw Streamer.Error.invalidResponse(item: update.item, fields: update.all, message: "The item name couldn't be identified.")
//                    }
//                    let response = try Response.Trade(update: update)
//                    input.send(value: (accountId, response))
//                } catch let error {
//                    input.send(error: error as! Streamer.Error)
//                }
//            case .unsubscribed:
//                input.sendCompleted()
//            case .subscriptionFailed(let underlyingError):
//                let items = accountIds.joined(separator: ", ")
//                let error: Streamer.Error = .subscriptionFailed(to: items, fields: fields.map { $0.rawValue }, error: underlyingError)
//                input.send(error: error)
//            case .subscriptionSucceeded, .updateLost(_,_):
//                break
//            }
//        }
//    }
//}
//
//extension Streamer.Request {
//    /// Possible fields to subscribe to when querying Trade data.
//    public enum Trade: String, StreamerFieldKeyable, CaseIterable, StreamerRequestItemNamePrefixable {
//        /// Trade confirmations for an account.
//        case confirmations = "CONFIRMS"
//        /// Open positions for an account.
//        case openPositions = "OPU"
//        /// Working order updates for an account.
//        case workingOrders = "WOU"
//        
//        internal static var prefix: String {
//            return "TRADE:"
//        }
//        
//        fileprivate static func accountId(itemName: String, requestedAccounts accountIds: [String]) -> String? {
//            guard itemName.hasPrefix(self.prefix) else { return nil }
//            let identifier = String(itemName.dropFirst(self.prefix.count))
//            return accountIds.first { $0 == identifier }
//        }
//        
//        public var keyPath: PartialKeyPath<Streamer.Response.Trade> {
//            switch self {
//            case .confirmations: return \Response.confirmation
//            case .openPositions: return \Response.openPosition
//            case .workingOrders: return \Response.workingOrder
//            }
//        }
//    }
//}
//
//extension Streamer.Response {
//    /// Response for a trade confirmation/update package.
//    public struct Trade: StreamerResponse, StreamerUpdatable {
//        public typealias Field = Streamer.Request.Trade
//        public let fields: Trade.Update
//        
//        /// The confirmation type is actually the same as the API confirmation.
//        public typealias Confirmation = APIResponseConfirmation
//        /// A trade confirmation.
//        public let confirmation: Confirmation?
//        
//        /// The open position type is actually the same as the API open position request.
//        public typealias OpenPosition = API.Response.Position
//        /// An open position update.
//        public let openPosition: OpenPosition?
//        
//        /// The working order type is actually the same as the API working order request.
//        public typealias WorkingOrder = API.Response.WorkingOrder
//        /// A working order update.
//        public let workingOrder: WorkingOrder?
//        
//        internal init(update: StreamerSubscriptionUpdate) throws {
//            let (values, fields) = try Update.make(update)
//            self.fields = fields
//            
//            self.confirmation = try values[.confirmations].map {
//                typealias T = API.Response.Confirmation
//                let data = try $0.jsonData(update: update)
//                
//                let decoder = Streamer.Codecs.jsonDecoder
//                let confirmation = try decoder.decode(T.self, from: data)
//                return (confirmation.isAccepted)
//                    ? try decoder.decode(T.Accepted.self, from: data)
//                    : try decoder.decode(T.Rejected.self, from: data)
//            }
//            
//            self.openPosition = try values[.openPositions].map {
//                let data = try $0.jsonData(update: update)
//                
//                let decoder = Streamer.Codecs.jsonDecoder
//                return try decoder.decode(OpenPosition.self, from: data)
//            }
//            
//            self.workingOrder = try values[.workingOrders].map {
//                let data = try $0.jsonData(update: update)
//                
//                let decoder = Streamer.Codecs.jsonDecoder
//                return try decoder.decode(WorkingOrder.self, from: data)
//            }
//        }
//    }
//}
//
//private extension String {
//    /// Transforms the given string (supposely representing a JSON object/array) into bytes (Data instance).
//    /// - parameter update: Instance containing information inc ase there is an error.
//    func jsonData(update: StreamerSubscriptionUpdate) throws -> Data {
//        return try self.data(using: .utf8)
//            ?! Streamer.Error.invalidResponse(item: update.item, fields: update.all, message: "The confirmation string couldn't be transformed into JSON data.")
//    }
//}
