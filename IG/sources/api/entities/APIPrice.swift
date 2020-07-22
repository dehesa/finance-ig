import Foundation
import Decimals

extension API {
    /// Historical market price snapshot.
    public struct Price: Equatable {
        /// Snapshot date.
        public let date: Date
        /// Open session price.
        public let open: Self.Point
        /// Close session price.
        public let close: Self.Point
        /// Lowest price.
        public let lowest: Self.Point
        /// Highest price.
        public let highest: Self.Point
        /// Last traded volume.
        ///
        /// This will generally be `nil` for non exchange traded instrument.
        public let volume: UInt?
        
        public static func == (lhs: API.Price, rhs: API.Price) -> Bool {
            (lhs.date == rhs.date) && (lhs.open == rhs.open) && (lhs.close == rhs.close) && (lhs.lowest == rhs.lowest) && (lhs.highest == rhs.highest) && (lhs.volume == rhs.volume)
        }
    }
}

extension API.Price {
    /// Price Snap.
    public struct Point: Equatable {
        /// Bid price (i.e. the price being offered  to buy an asset).
        public let bid: Decimal64
        /// Ask price (i.e. the price being asked to sell an asset).
        public let ask: Decimal64
        /// Last traded price.
        ///
        /// This will generally be `nil` for non-exchanged-traded instruments.
        public let lastTraded: Decimal64?
        
        /// The middle price between the *bid* and the *ask* price.
        @_transparent public var mid: Decimal64 {
            self.bid + Decimal64(5, power: -1).unsafelyUnwrapped * (self.ask - self.bid)
        }
    }
}

extension API.Price {
    /// Request allowance for prices.
    public struct Allowance {
        /// The date in which the current allowance period will end and the remaining allowance field is reset.
        public let resetDate: Date
        /// The number of data points still available to fetch within the current allowance period.
        public let remaining: UInt
        /// The number of data points the API key and account combination is allowed to fetch in any given allowance period.
        public let total: UInt
    }
}

// MARK: -

extension API.Price: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Self._Keys.self)
        self.date = try container.decode(Date.self, forKey: .date, with: DateFormatter.iso8601Broad)
        self.open = try container.decode(Self.Point.self, forKey: .open)
        self.close = try container.decode(Self.Point.self, forKey: .close)
        self.highest = try container.decode(Self.Point.self, forKey: .highest)
        self.lowest = try container.decode(Self.Point.self, forKey: .lowest)
        self.volume = try container.decodeIfPresent(UInt.self, forKey: .volume)
    }
    
    private enum _Keys: String, CodingKey {
        case date = "snapshotTimeUTC"
        case open = "openPrice"
        case close = "closePrice"
        case highest = "highPrice"
        case lowest = "lowPrice"
        case volume = "lastTradedVolume"
    }
}

extension API.Price.Point: Decodable {}

extension API.Price.Allowance: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        
        guard let response = decoder.userInfo[API.JSON.DecoderKey.responseHeader] as? HTTPURLResponse else {
            let ctx = DecodingError.Context(codingPath: container.codingPath, debugDescription: "The request/response values stored in the JSONDecoder 'userInfo' couldn't be found")
            throw DecodingError.valueNotFound(HTTPURLResponse.self, ctx)
        }
        
        guard let dateString = response.allHeaderFields[API.HTTP.Header.Key.date.rawValue] as? String,
            let date = DateFormatter.humanReadableLong.date(from: dateString) else {
                let message = "The date on the response header couldn't be processed"
                throw DecodingError.dataCorruptedError(forKey: .seconds, in: container, debugDescription: message)
        }
        
        let numSeconds = try container.decode(TimeInterval.self, forKey: .seconds)
        self.resetDate = date.addingTimeInterval(numSeconds)
        
        self.remaining = try container.decode(UInt.self, forKey: .remainingDataPoints)
        self.total = try container.decode(UInt.self, forKey: .totalDataPoints)
    }
    
    private enum _Keys: String, CodingKey {
        case seconds = "allowanceExpiry"
        case remainingDataPoints = "remainingAllowance"
        case totalDataPoints = "totalAllowance"
    }
}

