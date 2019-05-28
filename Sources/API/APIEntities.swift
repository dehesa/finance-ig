import Foundation

extension API {
    /// Application related entities (both for responses and requests).
    public enum Application {
        /// Application status in the platform.
        public enum Status: String, Codable {
            /// The application is enabled and thus ready to receive/send data.
            case enabled = "ENABLED"
            /// The application has been disabled by the developer.
            case disabled = "DISABLED"
            /// The application has been revoked by the admins.
            case revoked = "REVOKED"
        }
    }
}

extension API {
    /// Market related entities.
    public enum Market {
        /// The current status of the market.
        public enum Status: String, Codable {
            /// The market is open for trading.
            case tradeable = "TRADEABLE"
            /// The market is closed for the moment. Look at the market's opening hours for further information.
            case closed = "CLOSED"
            case editsOnly = "EDITS_ONLY"
            case onAuction = "ON_AUCTION"
            case onAuctionNoEdits = "ON_AUCTION_NO_EDITS"
            case offline = "OFFLINE"
            /// The market is suspended for trading temporarily.
            case suspended = "SUSPENDED"
        }
        
        /// Distance/Size preference.
        public struct Distance: Decodable {
            /// The distance value.
            public let value: Double
            /// The unit at which the `value` is measured against.
            public let unit: Unit
            
            public enum Unit: String, Decodable {
                case points = "POINTS"
                case percentage = "PERCENTAGE"
            }
        }
    }
}

extension API {
    /// The point when a trading position automatically closes is known as the expiry date (or expiration date).
    ///
    /// Expiry dates can vary from product to product. Spread bets, for example, always have a fixed expiry date. CFDs do not, unless they are on futures, digital 100s or options.
    public enum Expiry: Codable, ExpressibleByNilLiteral {
        /// DFBs (i.e. "Daily Funded Bets") run for as long as you choose to keep them open, with a default expiry some way off in the future.
        ///
        /// The cost of maintaining your DFB position is levied on your account each day: hence daily funded bet. You would generally use a daily funded bet to speculate on short-term market movements.
        case dailyFunded
        /// Forward bets will expire after a set period; instead of paying each day to keep the position open, the entire cost is taken into account in the spread.
        case forward(Date)
        /// No expiration date required.
        case none
        
        public init(nilLiteral: ()) {
            self = .none
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            guard !container.decodeNil() else {
                self = .none; return
            }
            
            let string = try container.decode(String.self)
            switch string {
            case CodingKeys.none.rawValue:
                self = .none
            case CodingKeys.dfb.rawValue, CodingKeys.dfb.rawValue.lowercased():
                self = .dailyFunded
            default:
                if let date = API.DateFormatter.dayMonthYear.date(from: string) {
                    self = .forward(date)
                } else if let date = API.DateFormatter.monthYear.date(from: string) {
                    self = .forward(date.lastDayOfMonth)
                } else if let date = API.DateFormatter.iso8601NoTimezone.date(from: string) {
                    self = .forward(date)
                } else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: API.DateFormatter.dayMonthYear.parseErrorLine(date: string))
                }
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .none:
                try container.encode(CodingKeys.none.rawValue)
            case .dailyFunded:
                try container.encode(CodingKeys.dfb.rawValue)
            case .forward(let date):
                let formatter = (date.isLastDayOfMonth) ? API.DateFormatter.monthYear : API.DateFormatter.dayMonthYear
                try container.encode(formatter.string(from: date))
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case dfb = "DFB"
            case none = "-"
        }
    }
}

extension API {
    /// Instrument related entities.
    public enum Instrument {
        /// The type of instrument.
        public enum Kind: String, Codable {
            /// A binary allows you to take a view on whether a specific outcome will or won't occur. For example, 'Will Wall Street be up at the close of the day?' If the answer is 'yes', the binary settles at 100. If the answer is 'no', the binary settles at 0. Your profit or loss is the difference between 100 (if the event occurs) or zero (if the event doesn't occur) and the level at which you 'bought' or 'sold'. Binary prices can be extremely volatile even when the underlying market is relatively static. A small movement in the underlying can make all the difference between the binary settling at 0 or 100.
            case binary = "BINARY"
            case bungeeCapped  = "BUNGEE_CAPPED"
            case bungeeCommodities  = "BUNGEE_COMMODITIES"
            case bungeeCurrencies = "BUNGEE_CURRENCIES"
            case bungeeIndices = "BUNGEE_INDICES"
            case commodities = "COMMODITIES"
            case currencies = "CURRENCIES"
            case indices = "INDICES"
            case optCommodities = "OPT_COMMODITIES"
            case optCurrencies = "OPT_CURRENCIES"
            case optIndices = "OPT_INDICES"
            case optRates = "OPT_RATES"
            case optShares = "OPT_SHARES"
            case rates = "RATES"
            case sectors = "SECTORS"
            case shares = "SHARES"
            case sprintMarket = "SPRINT_MARKET"
            case testMarket = "TEST_MARKET"
            case unknown = "UNKNOWN"
        }
    }
}

extension API {
    /// Position related entities (both for responses and requests).
    public enum Position {
        /// Position status.
        public enum Status: Decodable {
            case open
            case amended
            case partiallyClosed
            case closed
            case deleted
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                let value = try container.decode(String.self)
                switch value {
                case CodingKeys.openA.rawValue, CodingKeys.openB.rawValue: self = .open
                case CodingKeys.amended.rawValue: self = .amended
                case CodingKeys.partiallyClosed.rawValue: self = .partiallyClosed
                case CodingKeys.closedA.rawValue, CodingKeys.closedB.rawValue: self = .closed
                case CodingKeys.deleted.rawValue: self = .deleted
                default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "The status value \"\(value)\" couldn't be parsed.")
                }
            }
            
            private enum CodingKeys: String, CodingKey {
                case openA = "OPEN", openB = "OPENED"
                case amended = "AMENDED"
                case partiallyClosed = "PARTIALLY_CLOSED"
                case closedA = "FULLY_CLOSED", closedB = "CLOSED"
                case deleted = "DELETED"
            }
        }
        
        /// Deal direction.
        public enum Direction: String, Codable {
            case buy = "BUY"
            case sell = "SELL"
            
            public var oppossite: Direction {
                switch self {
                case .buy:  return .sell
                case .sell: return .buy
                }
            }
        }
        
        /// Indicates the price for a given instrument.
        public enum Boundary {
            /// The type of limit being set.
            public enum Limit {
                /// The limit or stop is given explicitly (as a value).
                case position(Double)
                /// The limit or stop is measured as the distance from a given level.
                case distance(Double)
            }
            
            /// The level/price at which the user doesn't want to incur more lose.
            public enum Stop {
                /// Absolute value of the stop (e.g. 1.653 USD/EUR).
                case position(Double)
                /// Distance from the buy/sell level where the stop will be placed.
                case distance(Double)
                /// A distance from the buy/sell level stop with the tweak that the stop will be moved towards the current level in case of a favourable trade.
                /// - parameter distance: The distance from the buy/sell price.
                /// - parameter increment: The increment step in pips.
                case trailing(distance: Double, increment: Double)
            }
        }
    }
}

extension API {
    /// Working order related entities.
    public enum WorkingOrder {
        /// The type of working order.
        public enum Kind: String, Codable {
            case limit = "LIMIT"
            case stop = "STOP"
        }
        
        /// Describes when the working order will expire.
        public enum Expiration {
            case tillCancelled
            case tillDate(Date)
            
            /// Designated initializer to create an expiration for working orders.
            /// - throws `Expiration.Error` if the raw value is invalid.
            internal init(_ rawValue: String, date: Date?) throws {
                switch rawValue {
                case CodingKeys.tillCancelled.rawValue:
                    self = .tillCancelled
                case CodingKeys.tillDate.rawValue:
                    guard let date = date else { throw Error.unavailableDate }
                    self = .tillDate(date)
                default:
                    throw Error.invalidExpirationRawValue(rawValue)
                }
            }
            
            fileprivate enum Error: Swift.Error {
                case invalidExpirationRawValue(String)
                case unavailableDate
            }
            
            internal var rawValue: String {
                switch self {
                case .tillCancelled: return CodingKeys.tillCancelled.rawValue
                case .tillDate(_): return CodingKeys.tillDate.rawValue
                }
            }
            
            private enum CodingKeys: String {
                case tillCancelled = "GOOD_TILL_CANCELLED"
                case tillDate = "GOOD_TILL_DATE"
            }
        }
        
        /// Indicates the price for a given instrument.
        public enum Boundary {
            /// The type of limit being set.
            public typealias Limit = API.Position.Boundary.Limit
            
            /// The level/price at which the user doesn't want to incur more lose.
            public typealias Stop = Limit
        }
    }
}

/// Reflect the boundaries for a deal level.
public protocol APIPositionBoundaries {
    /// The limit level at which the user is happy with his/her profits.
    var limit: API.Position.Boundary.Limit? { get }
    /// The stop level at which the user don't want to take more losses.
    var stop: API.Position.Boundary.Stop? { get }
}

extension APIPositionBoundaries {
    /// Returns a boolean indicating whether there are no boundaries set.
    public var isEmpty: Bool { return (self.limit == nil) && (self.stop == nil) }
}

