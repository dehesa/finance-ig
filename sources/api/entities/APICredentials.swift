import Foundation

extension API {
    /// Credentials used within the API session.
    public struct Credentials: Equatable {
        /// API key given by the IG platform identifying the usage of the IG endpoints.
        public let key: API.Key
        /// Client identifier.
        public let client: IG.Client.Identifier
        /// Active account identifier.
        public internal(set) var account: IG.Account.Identifier
        /// Lightstreamer endpoint for subscribing to account and price updates.
        public let streamerURL: URL
        /// Timezone of the active account.
        public let timezone: TimeZone
        /// The actual token values/headers.
        public internal(set) var token: API.Token
    }
}

extension API {
    /// Storage for one of the login types supported by the servers.
    public struct Token: Equatable {
        /// Expiration date for the underlying token (only references the access token).
        public let expirationDate: Date
        /// The actual token values.
        public let value: Self.Kind
        
        /// Initializes a token with hardcoded values.
        /// - parameter value: The type of token used in the credentials (whether certificate or OAuth).
        /// - parameter expirationDate: When is the provided token expiring.
        @_transparent public init(_ value: Self.Kind, expirationDate: Date) {
            self.expirationDate = expirationDate
            self.value = value
        }
        
        /// Initializes a token with hardcoded values (and a expiration date offset).
        /// - parameter value: The type of token used in the credentials (whether certificate or OAuth).
        /// - parameter seconds: The amount of seconds this token will expires in.
        @_transparent public init(_ value: Self.Kind, expiresIn seconds: TimeInterval) {
            self.expirationDate = Date(timeIntervalSinceNow: seconds)
            self.value = value
        }
        
        /// Returns `true` when the `expirationDate` is in the past.
        @_transparent public var isExpired: Bool {
            self.expirationDate < Date()
        }
    }
}

extension API.Token {
    /// The type of token stored.
    public enum Kind: Equatable {
        /// Session token (v2) with a CST and Security tokens.
        case certificate(access: String, security: String)
        /// OAuth token (v3) with access and refresh tokens.
        case oauth(access: String, refresh: String, scope: String, type: String)
    }
}

// MARK: -

extension API.Credentials: Codable {
    /// Key-value pairs to be added to the request headers.
    /// - returns: The key-value pairs of the underlying credentials.
    internal var requestHeaders: [API.HTTP.Header.Key:String] {
        var result: [API.HTTP.Header.Key:String] = [.apiKey: self.key.description]
        switch self.token.value {
        case .certificate(let access, let security):
            result[.clientSessionToken] = access
            result[.securityToken] = security
        case .oauth(let access, _, _, let type):
            result[.account] = self.account.description
            result[.authorization] = "\(type) \(access)"
        }
        return result
    }
}

extension API.Token: Codable {}

extension API.Token.Kind: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _Keys.self)
        let access = try container.decode(String.self, forKey: .access)
        if container.contains(.security) {
            let security = try container.decode(String.self, forKey: .security)
            self = .certificate(access: access, security: security)
        } else {
            let refresh = try container.decode(String.self, forKey: .refresh)
            let scope = try container.decode(String.self, forKey: .scope)
            let type = try container.decode(String.self, forKey: .type)
            self = .oauth(access: access, refresh: refresh, scope: scope, type: type)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: _Keys.self)
        switch self {
        case .certificate(let access, let security):
            try container.encode(access, forKey: .access)
            try container.encode(security, forKey: .security)
        case .oauth(let access, let refresh, let scope, let type):
            try container.encode(access, forKey: .access)
            try container.encode(refresh, forKey: .refresh)
            try container.encode(scope, forKey: .scope)
            try container.encode(type, forKey: .type)
        }
    }
    
    private enum _Keys: String, CodingKey {
        case access, security
        case refresh, scope, type
    }
}
