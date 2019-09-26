import Foundation

extension IG.API {
    /// Namespace for commonly used value/class types related to deals.
    public enum Deal {}
}
#warning("API: Uncomment")
//extension IG.API.Position {
//    /// Describes how the user's order must be executed.
//    public enum Order {
//        /// A market order is an instruction to buy or sell at the best available price for the size of your order.
//        ///
//        /// When using this type of order you choose the size and direction of your order, but not the price (a level cannot be specified).
//        /// - note: Not applicable to BINARY instruments.
//        case market
//        /// A limit fill or kill order is an instruction to buy or sell in a specified size within a specified price limit, which is either filled completely or rejected.
//        ///
//        /// Provided the market price is within the specified limit and there is sufficient volume available, the order will be filled at the prevailing market price.
//        ///
//        /// The entire order will be rejected if:
//        /// - The market price is outside your specified limit (higher for buy orders, lower for sell orders).
//        /// - There is insufficient volume available to satisfy the full order size.
//        case limit(level: Decimal)
//        /// Quote orders get executed at the specified level.
//        ///
//        /// The level has to be accompanied by a valid quote id (i.e. Lightstreamer price quote identifier).
//        ///
//        /// A quoteID is the two-way market price that we are making for a given instrument. Because it is two-way, you can 'buy' or 'sell', according to whether you think the price will rise or fall
//        /// - note: This type is only available subject to agreement with IG.
//        case quote(id: String, level: Decimal)
//
//        /// Returns the level for the order if it is known.
//        var level: Decimal? {
//            switch self {
//            case .market: return nil
//            case .limit(let level): return level
//            case .quote(_, let level): return level
//            }
//        }
//
//        /// The order fill strategy.
//        public enum Strategy: String, Encodable {
//            /// Execute and eliminate.
//            case execute = "EXECUTE_AND_ELIMINATE"
//            /// Fill or kill.
//            case fillOrKill = "FILL_OR_KILL"
//        }
//    }
//}
//
//extension IG.API.WorkingOrder {
//    /// Working order type.
//    public enum Kind: String, Codable {
//        /// An instruction to deal if the price moves to a more favourable level.
//        ///
//        /// This is an order to open a position by buying when the market reaches a lower level than the current price, or selling short when the market hits a higher level than the current price.
//        /// This is suitable if you think the market price will **change direction** when it hits a certain level.
//        case limit = "LIMIT"
//        /// This is an order to buy when the market hits a higher level than the current price, or sell when the market hits a lower level than the current price.
//        /// This is suitable if you think the market will continue **moving in the same direction** once it hits a certain level.
//        case stop = "STOP"
//    }
//
//    /// Describes when the working order will expire.
//    public enum Expiration {
//        /// The order remains in place till it is explicitly cancelled.
//        case tillCancelled
//        /// The order remains in place till it is fulfill or the associated date is reached.
//        case tillDate(Date)
//
//        internal enum CodingKeys: String {
//            case tillCancelled = "GOOD_TILL_CANCELLED"
//            case tillDate = "GOOD_TILL_DATE"
//        }
//    }
//}
