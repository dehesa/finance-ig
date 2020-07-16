import Foundation
import Decimals

extension API.Node {
    /// Market data hanging from a hierarchical node.
    public struct Market: Decodable {
        /// The market's instrument.
        public let instrument: Self.Instrument
        /// The market's prices.
        public let snapshot: Self.Snapshot

        public init(from decoder: Decoder) throws {
            self.instrument = try .init(from: decoder)
            self.snapshot = try .init(from: decoder)
        }
    }
}

extension API.Node.Market {
    /// Market's instrument properties.
    public struct Instrument: Decodable {
        /// Instrument epic identifier.
        public let epic: Market.Epic
        /// Exchange identifier for the instrument.
        public let exchangeIdentifier: String?
        /// Instrument name.
        public let name: String
        /// Instrument type.
        public let type: API.Market.Instrument.Kind
        /// Instrument expiry period.
        public let expiry: Market.Expiry
        /// Minimum amount of unit that an instrument can be dealt in the market. It's the relationship between unit and the amount per point.
        /// - note: This property is set when querying nodes, but `nil` when querying markets.
        public let lotSize: UInt?
        /// `true` if streaming prices are available, i.e. the market is tradeable and the client holds the necessary access permission.
        public let isAvailableByStreaming: Bool
        /// `true` if Over-The-Counter tradeable.
        /// - note: This property is set when querying nodes, but `nil` when querying markets.
        public let isOTCTradeable: Bool?

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: _CodingKeys.self)
            self.epic = try container.decode(IG.Market.Epic.self, forKey: .epic)
            self.exchangeIdentifier = try container.decodeIfPresent(String.self, forKey: .exchangeId)
            self.name = try container.decode(String.self, forKey: .name)
            self.type = try container.decode(API.Market.Instrument.Kind.self, forKey: .type)
            self.expiry = try container.decodeIfPresent(Market.Expiry.self, forKey: .expiry) ?? .none
            self.lotSize = try container.decodeIfPresent(UInt.self, forKey: .lotSize)
            self.isAvailableByStreaming = try container.decode(Bool.self, forKey: .isAvailableByStreaming)
            self.isOTCTradeable = try container.decodeIfPresent(Bool.self, forKey: .isOTCTradeable)
        }

        private enum _CodingKeys: String, CodingKey {
            case epic, exchangeId
            case name = "instrumentName"
            case type = "instrumentType"
            case expiry, lotSize
            case isAvailableByStreaming = "streamingPricesAvailable"
            case isOTCTradeable = "otcTradeable"
        }
    }
}

extension API.Node.Market {
    /// A snapshot of the state of a market.
    public struct Snapshot: Decodable {
        /// Time of the last price update.
        /// - attention: Although a full date is given, only the hours:minutes:seconds are meaningful.
        public let date: Date
        /// Pirce delay marked in minutes.
        public let delay: TimeInterval
        /// Describes the current status of a given market
        public let status: API.Market.Status
        /// The state of the market price at the time of the snapshot.
        public let price: API.Market.Price?
        /// Multiplying factor to determine actual pip value for the levels used by the instrument.
        public let scalingFactor: Decimal64

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: _CodingKeys.self)

            guard let responseDate = decoder.userInfo[API.JSON.DecoderKey.responseDate] as? Date else {
                throw DecodingError.valueNotFound(Date.self, .init(codingPath: container.codingPath, debugDescription: "The decoder was expected to have the response date in its userInfo dictionary"))
            }
            let timeDate = try container.decode(Date.self, forKey: .lastUpdate, with: DateFormatter.time)
            guard let update = responseDate.mixComponents([.year, .month, .day], withDate: timeDate, [.hour, .minute, .second], calendar: UTC.calendar, timezone: UTC.timezone) else {
                throw DecodingError.dataCorruptedError(forKey: .lastUpdate, in: container, debugDescription: "The update time couldn't be inferred")
            }

            if update > responseDate {
                self.date = try UTC.calendar.date(byAdding: DateComponents(day: -1), to: update) ?> DecodingError.dataCorruptedError(forKey: .lastUpdate, in: container, debugDescription: "Error processing update time")
            } else {
                self.date = update
            }

            self.delay = try container.decode(TimeInterval.self, forKey: .delay)
            self.status = try container.decode(API.Market.Status.self, forKey: .status)
            self.price = try API.Market.Price(from: decoder)
            self.scalingFactor = try container.decode(Decimal64.self, forKey: .scalingFactor)
        }

        private enum _CodingKeys: String, CodingKey {
            case lastUpdate = "updateTimeUTC"
            case delay = "delayTime"
            case status = "marketStatus"
            case scalingFactor
        }
    }
}
