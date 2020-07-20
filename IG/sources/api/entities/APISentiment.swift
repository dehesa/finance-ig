import Foundation
import Decimals

extension API.Market {
    /// The sentiment of all users of the platform towards a targeted market.
    public struct Sentiment {
        /// The name of a natural grouping of a set of IG markets
        ///
        /// It typically represents the underlying 'real-world' market. For example, `VOD-UK` represents Vodafone Group PLC (UK).
        /// This identifier is primarily used in the our market research services, such as client sentiment, and may be found on the /market/{epic} service
        public let marketIdentifier: String
        /// Percentage long positions (over 100%).
        public let longs: Decimal64
        /// Percentage short positions (over 100%).
        public let shorts: Decimal64
    }
}

// MARK: -

extension API.Market.Sentiment: Decodable {
    private enum CodingKeys: String, CodingKey {
        case marketIdentifier = "marketId"
        case longs = "longPositionPercentage"
        case shorts = "shortPositionPercentage"
    }
}
