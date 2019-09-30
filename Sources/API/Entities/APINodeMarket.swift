import Foundation

extension IG.API.Node {
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

extension IG.API.Node.Market {
    /// Market's instrument properties.
    public struct Instrument: Decodable {
        /// Instrument epic identifier.
        public let epic: IG.Market.Epic
        /// Exchange identifier for the instrument.
        public let exchangeIdentifier: String?
        /// Instrument name.
        public let name: String
        /// Instrument type.
        public let type: IG.API.Market.Instrument.Kind
        /// Instrument expiry period.
        public let expiry: IG.Market.Expiry
        /// Minimum amount of unit that an instrument can be dealt in the market. It's the relationship between unit and the amount per point.
        /// - note: This property is set when querying nodes, but `nil` when querying markets.
        public let lotSize: UInt?
        /// `true` if streaming prices are available, i.e. the market is tradeable and the client holds the necessary access permission.
        public let isAvailableByStreaming: Bool
        /// `true` if Over-The-Counter tradeable.
        /// - note: This property is set when querying nodes, but `nil` when querying markets.
        public let isOTCTradeable: Bool?

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.epic = try container.decode(IG.Market.Epic.self, forKey: .epic)
            self.exchangeIdentifier = try container.decodeIfPresent(String.self, forKey: .exchangeId)
            self.name = try container.decode(String.self, forKey: .name)
            self.type = try container.decode(IG.API.Market.Instrument.Kind.self, forKey: .type)
            self.expiry = try container.decodeIfPresent(IG.Market.Expiry.self, forKey: .expiry) ?? .none
            self.lotSize = try container.decodeIfPresent(UInt.self, forKey: .lotSize)
            self.isAvailableByStreaming = try container.decode(Bool.self, forKey: .isAvailableByStreaming)
            self.isOTCTradeable = try container.decodeIfPresent(Bool.self, forKey: .isOTCTradeable)
        }

        private enum CodingKeys: String, CodingKey {
            case epic, exchangeId
            case name = "instrumentName"
            case type = "instrumentType"
            case expiry, lotSize
            case isAvailableByStreaming = "streamingPricesAvailable"
            case isOTCTradeable = "otcTradeable"
        }
    }
}

extension IG.API.Node.Market {
    /// A snapshot of the state of a market.
    public struct Snapshot: Decodable {
        /// Time of the last price update.
        /// - attention: Although a full date is given, only the hours:minutes:seconds are meaningful.
        public let date: Date
        /// Pirce delay marked in minutes.
        public let delay: TimeInterval
        /// Describes the current status of a given market
        public let status: IG.API.Market.Status
        /// The state of the market price at the time of the snapshot.
        public let price: IG.API.Market.Price?
        /// Multiplying factor to determine actual pip value for the levels used by the instrument.
        public let scalingFactor: Decimal

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)

            let responseDate = try decoder.userInfo[IG.API.JSON.DecoderKey.responseDate] as? Date ?! DecodingError.valueNotFound(Date.self, .init(codingPath: container.codingPath, debugDescription: "The decoder was expected to have the response date in its userInfo dictionary"))
            let timeDate = try container.decode(Date.self, forKey: .lastUpdate, with: IG.API.Formatter.time)
            let update = try responseDate.mixComponents([.year, .month, .day], withDate: timeDate, [.hour, .minute, .second], calendar: IG.UTC.calendar, timezone: IG.UTC.timezone) ?!
                DecodingError.dataCorruptedError(forKey: .lastUpdate, in: container, debugDescription: "The update time couldn't be inferred")

            if update > responseDate {
                let newDate = try IG.UTC.calendar.date(byAdding: DateComponents(day: -1), to: update) ?!
                    DecodingError.dataCorruptedError(forKey: .lastUpdate, in: container, debugDescription: "Error processing update time")
                self.date = newDate
            } else {
                self.date = update
            }

            self.delay = try container.decode(TimeInterval.self, forKey: .delay)
            self.status = try container.decode(IG.API.Market.Status.self, forKey: .status)
            self.price = try IG.API.Market.Price(from: decoder)
            self.scalingFactor = try container.decode(Decimal.self, forKey: .scalingFactor)
        }

        private enum CodingKeys: String, CodingKey {
            case lastUpdate = "updateTimeUTC"
            case delay = "delayTime"
            case status = "marketStatus"
            case scalingFactor
        }
    }
}

extension IG.API.Node.Market: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.API.printableDomain).\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("instrument", self.instrument) {
            $0.append("epic", $1.epic)
            $0.append("exchange ID", $1.exchangeIdentifier)
            $0.append("name", $1.name)
            $0.append("type", $1.type)
            $0.append("expiry", $1.expiry.debugDescription)
            $0.append("lot size", $1.lotSize)
            $0.append("available by streaming", $1.isAvailableByStreaming)
            $0.append("OTC tradeable", $1.isOTCTradeable)
        }
        result.append("snapshot", self.snapshot) {
            $0.append("date", $1.date, formatter: IG.Formatter.timestamp.deepCopy(timeZone: .current))
            $0.append("delay", $1.delay)
            $0.append("status", $1.status)
            $0.append("price", $1.price) {
                $0.append("ask", $1.ask)
                $0.append("bid", $1.bid)
                $0.append("range", "\($1.lowest)...\($1.highest)")
                $0.append("change", "\($1.change.net) (net) or \($1.change.percentage) %")
            }
            $0.append("scaling factor", $1.scalingFactor)
        }
        return result.generate()
    }
}
