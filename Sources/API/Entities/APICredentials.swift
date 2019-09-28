import Foundation

extension IG.API {
    /// Credentials used within the API session.
    public struct Credentials {
        /// Client identifier.
        public let client: IG.Client.Identifier
        /// Active account identifier.
        public internal(set) var account: IG.Account.Identifier
        /// Lightstreamer endpoint for subscribing to account and price updates.
        public let streamerURL: URL
        /// Timezone of the active account.
        public let timezone: TimeZone
        /// API key given by the IG platform identifying the usage of the IG endpoints.
        public let key: IG.API.Key
        /// The actual token values/headers.
        public internal(set) var token: Self.Token
        
        /// Creates a credentials structure from hardcoded data.
        public init(client: IG.Client.Identifier, account: IG.Account.Identifier, key: IG.API.Key, token: Self.Token, streamerURL: URL, timezone: TimeZone) {
            self.client = client
            self.account = account
            self.streamerURL = streamerURL
            self.timezone = timezone
            self.key = key
            self.token = token
        }
        
        /// Key-value pairs to be added to the request headers.
        /// - returns: The key-value pairs of the underlying credentials.
        internal var requestHeaders: [IG.API.HTTP.Header.Key:String] {
            var result: [IG.API.HTTP.Header.Key:String] = [.apiKey: self.key.rawValue]
            switch self.token.value {
            case .certificate(let access, let security):
                result[.clientSessionToken] = access
                result[.securityToken] = security
            case .oauth(let access, _, _, let type):
                result[.account] = self.account.rawValue
                result[.authorization] = "\(type) \(access)"
            }
            return result
        }
    }
}

extension IG.API.Credentials {
    /// Storage for one of the login types supported by the servers.
    public struct Token {
        /// Expiration date for the underlying token (only references the access token).
        public let expirationDate: Date
        /// The actual token values.
        public let value: Self.Kind
        
        /// Initializes a token with hardcoded values.
        /// - parameter value: The type of token used in the credentials (whether certificate or OAuth).
        /// - parameter expirationDate: When is the provided token expiring.
        public init(_ value: Self.Kind, expirationDate: Date) {
            self.expirationDate = expirationDate
            self.value = value
        }
        
        /// Initializes a token with hardcoded values (and a expiration date offset).
        /// - parameter value: The type of token used in the credentials (whether certificate or OAuth).
        /// - parameter seconds: The amount of seconds this token will expires in.
        public init(_ value: Self.Kind, expiresIn seconds: TimeInterval) {
            self.expirationDate = Date(timeIntervalSinceNow: seconds)
            self.value = value
        }
    }
}

extension IG.API.Credentials.Token {
    /// The type of token stored.
    public enum Kind {
        /// Session token (v2) with a CST and Security tokens.
        case certificate(access: String, security: String)
        /// OAuth token (v3) with access and refresh tokens.
        case oauth(access: String, refresh: String, scope: String, type: String)
    }
}

// MARK: - Debug helpers

extension IG.API.Credentials: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.API.printableDomain).\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("client ID", self.client)
        result.append("account ID", self.account)
        result.append("API key", self.key)
        result.append("streamer URL", self.streamerURL.path)
        result.append("timezone", self.timezone.description)
        result.append("token", self.token.value) {
            switch $1 {
            case .certificate(let access, let security):
                $0.append("cst", access)
                $0.append("security", security)
            case .oauth(let access, let refresh, let scope, let type):
                $0.append("access", access)
                $0.append("refresh", refresh)
                $0.append("scope", scope)
                $0.append("type", type)
            }
        }
        return result.generate()
    }
}

extension IG.API.Credentials.Token.Kind: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result: IG.DebugDescription
        let title = "\(IG.API.Credentials.printableDomain).Token"
        switch self {
        case .certificate(let access, let security):
            result = .init(title + " - Certificate")
            result.append("cst", access)
            result.append("security", security)
        case .oauth(let access, let refresh, let scope, let type):
            result = .init(title + " - OAuth")
            result.append("access", access)
            result.append("refresh", refresh)
            result.append("scope", scope)
            result.append("type", type)
        }
        return result.generate()
    }
}
