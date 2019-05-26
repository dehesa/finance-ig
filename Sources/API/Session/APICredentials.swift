import Foundation

extension API {
    /// Credentials used within the API session.
    public struct Credentials {
        /// Client identifier.
        public let clientId: Int
        /// Active account identifier.
        public let accountId: String
        /// Lightstreamer endpoint for subscribing to account and price updates.
        public let streamerURL: URL
        /// Timezone of the active account.
        public let timezone: TimeZone
        /// API key given by the IG platform identifying the usage of the IG endpoints.
        public let apiKey: String
        /// The actual token values/headers.
        public let token: Token
        
        /// Creates a credentials structure from hardcoded data.
        public init(clientId: Int, accountId: String, apiKey: String, token: Token, streamerURL: URL, timezone: TimeZone) {
            self.clientId = clientId
            self.accountId = accountId
            self.streamerURL = streamerURL
            self.timezone = timezone
            self.apiKey = apiKey
            self.token = token
        }
        
        /// Creates a new credentials instance from a previous one and a new token.
        /// - parameter credentials: The credential instance where to get all properties except the token one.
        /// - parameter token: The new valid tokens.
        internal init(_ credentials: API.Credentials, token: API.Credentials.Token) {
            self.apiKey = credentials.apiKey
            self.clientId = credentials.clientId
            self.accountId = credentials.accountId
            self.streamerURL = credentials.streamerURL
            self.timezone = credentials.timezone
            self.token = token
        }
        
        /// Request headers for the underlying credentials.
        internal var requestHeaders: [API.HTTP.Header.Key:String] {
            var result: [API.HTTP.Header.Key:String] = [.apiKey: self.apiKey]
            switch self.token.value {
            case .certificate(let access, let security):
                result[.clientSessionToken] = access
                result[.securityToken] = security
            case .oauth(let access, _, _, let type):
                result[.account] = self.accountId
                result[.authorization] = "\(type) \(access)"
            }
            return result
        }
    }
}

extension API.Credentials: CustomDebugStringConvertible {
    /// Storage for one of the login types supported by the servers.
    public struct Token {
        /// Expiration date for the underlying token (only references the access token).
        public let expirationDate: Date
        /// The actual token values.
        public let value: Kind
        
        /// Initializes a token with hardcoded values.
        public init(_ value: Kind, expirationDate: Date) {
            self.expirationDate = expirationDate
            self.value = value
        }
        
        /// The type of token stored.
        public enum Kind: CustomDebugStringConvertible {
            /// Session token (v2) with a CST and Security tokens.
            case certificate(access: String, security: String)
            /// OAuth token (v3) with access and refresh tokens.
            case oauth(access: String, refresh: String, scope: String, type: String)
            
            public var debugDescription: String {
                switch self {
                case .certificate(let access, let security):
                    return """
                    Token CST {
                        Access: \(access)
                        Security: \(security)
                    }
                    """
                case .oauth(let access, let refresh, _, let type):
                    return """
                    Token OAuth {
                        Access: \(type) \(access)
                        Refresh: \(refresh)
                    }
                    """
                }
            }
        }
    }
    
    public var debugDescription: String {
        var result = """
        API credentials {
            Client ID:       \(self.clientId)
            Account ID:      \(self.accountId)
            API key:         \(self.apiKey)
            Streamer URL:    \(self.streamerURL)
            Timezone:        \(self.timezone)
        """
        
        switch self.token.value {
        case .certificate(let access, let security):
            result.append("\n    CST token:       \(access)")
            result.append("\n    Security header: \(security)")
        case .oauth(let access, let refresh, let scope, let type):
            result.append("\n    OAuth token:     \(access)")
            result.append("\n    OAuth scope:     \(scope)")
            result.append("\n    OAuth type:      \(type)")
            result.append("\n    Refresh token:   \(refresh)")
        }
        
        result.append("\n}")
        return result
    }
}

extension API.Request {
    /// Data needed to requests API credentials.
    public struct Login: CustomDebugStringConvertible {
        /// API key given by the IG platform identifying the usage of the IG endpoints.
        public let apiKey: String
        /// String representing an IG account.
        public let accountId: String
        /// User name to log in into an IG account.
        public let username: String
        /// User password to log in into an IG account.
        public let password: String
        
        /// Designated initializer for the Login Request.
        /// - parameter apiKey: The API key provided by your application developer.
        /// - parameter accountId: The targeted user's account identifier.
        /// - parameter username: The targeted user's name/identifier.
        /// - parameter password: The targeted user's password.
        /// - throws: `API.Error` if any of the passed argument is invalid.
        public init(apiKey: String, accountId: String, username: String, password: String) throws {
            let length: (apiKey: Int, accountId: Int) = (40, 5)
            let errorBlurb = "Login request failed!"
            
            guard apiKey.utf8.count == length.apiKey else {
                throw API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) The API key provided must be exactly \(length.apiKey) UTF8 characters. The one provided (\"\(apiKey)\") has \(apiKey.utf8.count) characters.")
            }
            
            guard accountId.utf8.count == length.accountId else {
                throw API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) The accountId provided must be exactly \(length.accountId) UTF8 characteres. The one provided (\"\(accountId)\") has \(accountId.utf8.count) characters.")
            }
            
            guard !username.isEmpty else {
                throw API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) The username provided cannot be empty.")
            }
            
            guard !password.isEmpty else {
                throw API.Error.invalidRequest(underlyingError: nil, message: "\(errorBlurb) The password provided cannot be empty.")
            }
            
            self.apiKey = apiKey
            self.accountId = accountId
            self.username = username
            self.password = password
        }
        
        public var debugDescription: String {
            return """
             API login {
                Account ID: \(self.accountId)
                API key:    \(self.apiKey)
                Username:   \(self.username)
                Password:   \(self.password)
             }
             """
        }
    }
}
