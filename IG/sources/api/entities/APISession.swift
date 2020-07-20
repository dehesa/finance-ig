import Foundation

extension API {
    /// Representation of a dealing session.
    public struct Session {
        /// Client identifier.
        public let client: IG.Client.Identifier
        /// Active account identifier.
        public let account: IG.Account.Identifier
        /// Lightstreamer endpoint for subscribing to account and price updates.
        public let streamerURL: URL
        /// Timezone of the active account.
        public let timezone: TimeZone
        /// The language locale to use on the platform
        public let locale: Locale
        /// The default currency used in this session.
        public let currencyCode: Currency.Code
    }
}

extension API.Session {
    /// The session status.
    public enum Status: Equatable {
        /// There are no credentials within the current session.
        case logout
        /// There are credentials and they haven't yet expired.
        case ready(till: Date)
        /// There are credentials, but they have already expired.
        case expired
    }
    
    /// Payload received when accounts are switched.
    public struct Settings {
        /// Boolean indicating whether trailing stops are currently enabled for the given account.
        public let isTrailingStopEnabled: Bool
        /// Boolean indicating whether it is possible to make "deals" on the given account.
        public let isDealingEnabled: Bool
        /// Boolean indicating whther the demo account is active.
        public let hasActiveDemoAccounts: Bool
        /// Boolean indicating whether the live account is active.
        public let hasActiveLiveAccounts: Bool
    }
}

// MARK: -

extension API.Session: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        self.client = try container.decode(IG.Client.Identifier.self, forKey: .client)
        self.account = try container.decode(IG.Account.Identifier.self, forKey: .account)
        let offset = try container.decode(Int.self, forKey: .timezoneOffset)
        self.timezone = try TimeZone(secondsFromGMT: offset * 3600) ?> DecodingError.dataCorruptedError(forKey: .timezoneOffset, in: container, debugDescription: "The timezone couldn't be parsed into a Foundation TimeZone structure")
        self.streamerURL = try container.decode(URL.self, forKey: .streamerURL)
        self.locale = Locale(identifier: try container.decode(String.self, forKey: .locale))
        self.currencyCode = try container.decode(Currency.Code.self, forKey: .currencyCode)
    }
    
    private enum _Keys: String, CodingKey {
        case client = "clientId"
        case account = "accountId"
        case timezoneOffset, locale
        case currencyCode = "currency"
        case streamerURL = "lightstreamerEndpoint"
    }
}

extension API.Session.Settings: Decodable {
    private enum CodingKeys: String, CodingKey {
        case isTrailingStopEnabled = "trailingStopsEnabled"
        case isDealingEnabled = "dealingEnabled"
        case hasActiveDemoAccounts, hasActiveLiveAccounts
    }
}
