import ReactiveSwift
import Foundation

extension API.Request.Session {
    
    // MARK: POST /session

    /// Creates a trading session, obtaining session tokens for subsequent API access.
    ///
    /// Region-specific login restrictions may apply.
    /// - note: No credentials are needed for this endpoint.
    /// - todo: Password encryption doesn't work! Currently it is ignoring the parameter.
    /// - parameter key: API key given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter user: User name and password to log in into an IG account.
    /// - parameter encryptPassword: Boolean indicating whether the given password shall be encrypted before sending it to the server.
    /// - returns: `SignalProducer` that when started it will log in the user passed in the `info` parameter.
    internal func loginCertificate(key: API.Key, user: API.User, encryptPassword: Bool = false) -> SignalProducer<API.Credentials,API.Error> {
        return SignalProducer(api: self.api)
            .request(.post, "session", version: 2, credentials: false, headers: { (_,_) in [.apiKey: key.rawValue] }, body: { (_,_) in
                let payload = Self.PayloadCertificate(user: user, encryptedPassword: encryptPassword)
                let data = try JSONEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (r: API.Session.Certificate) in
                let token = API.Credentials.Token(.certificate(access: r.tokens.accessToken, security: r.tokens.securityToken), expirationDate: r.tokens.expirationDate)
                return API.Credentials(client: r.session.client, account: r.account.identifier, key: key, token: token, streamerURL: r.session.streamerURL, timezone: r.session.timezone)
            }
    }
    
    // MARK: GET /session?fetchSessionTokens=true
    
    /// It regenerates certificate credentials from the current session (whether OAuth or Certificate logged in).
    /// - returns: `API.Credentials.Token` always returning a `.certificate`.
    internal func refreshCertificate() -> SignalProducer<API.Credentials.Token,API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "session", version: 1, credentials: true, queries: { (_,_) in
                [URLQueryItem(name: "fetchSessionTokens", value: "true")]
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (r: API.Session.WrapperCertificate) in
                .init(.certificate(access: r.token.accessToken, security: r.token.securityToken), expirationDate: r.token.expirationDate)
            }
    }
    
    /// Returns the user's session details for the credentials given as arguments and regenerates the certificate tokens.
    /// - note: No credentials (besides the provided ones as parameter) are needed for this endpoint.
    /// - parameter apiKey: API key given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter token: The credentials for the user session to query.
    /// - returns: The session data and `API.Credentials.Token` always set up to `.certificate`.
    internal func refreshCertificate(apiKey: String, token: API.Credentials.Token) -> SignalProducer<(API.Session,API.Credentials.Token),API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "session", version: 1, credentials: false, queries: { (_,_) in
                [URLQueryItem(name: "fetchSessionTokens", value: "true")]
            }, headers: { (_,_) in
                var result = [API.HTTP.Header.Key.apiKey: apiKey]
                switch token.value {
                case .certificate(let access, let security):
                    result[.clientSessionToken] = access
                    result[.securityToken] = security
                case .oauth(let access, _, _, let type):
                    result[.authorization] = "\(type) \(access)"
                }
                return result
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (r: API.Session.WrapperCertificate) in
                let token = API.Credentials.Token(.certificate(access: r.token.accessToken, security: r.token.securityToken), expirationDate: r.token.expirationDate)
                return (r.session, token)
            }
    }
    
    // MARK: GET /session/encryptionKey
    
    /// Returns an encryption key to use in order to send the user password in an encrypted form.
    ///
    /// To encrypt a password:
    /// 1. call /session/encryptionKey which gives a key and timestamp
    /// 2. create a RSA token using the key.
    /// 3. encrypt password + "|" + timestamp
    /// - parameter key: The API key which the encryption key will be associated to.
    /// - returns: `SignalProducer` returning the session's encryption key with the key's timestamp.
    /// - note: No credentials are needed for this endpoint.
    fileprivate func generateEncryptionKey(key: API.Key) -> SignalProducer<API.Session.EncryptionKey,API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "session/encryptionKey", version: 1, credentials: false, headers: { (_,_) in [.apiKey: key.rawValue] })
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
    }
}

// MARK: - Supporting Entities

// MARK: Request Entities

extension API.Request.Session {
    /// Log-in through certificate required payload.
    private struct PayloadCertificate: Encodable {
        let user: API.User
        let encryptedPassword: Bool
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Self.CodingKeys.self)
            try container.encode(self.user.name, forKey: .identifier)
            try container.encode(self.user.password, forKey: .password)
            try container.encode(self.encryptedPassword, forKey: .encryptedPassword)
        }
        
        private enum CodingKeys: String, CodingKey {
            case identifier, password, encryptedPassword
        }
    }
}

// MARK: Response Entities

extension API.Session {
    /// CST credentials used to access the IG platform.
    fileprivate struct Certificate: Decodable {
        /// Logged session
        let session: Self.Session
        /// Active account identifier.
        let account: Self.Account
        /// The certificate tokens granting access to the platform.
        let tokens: Self.Token
        
        init(from decoder: Decoder) throws {
            self.session = try .init(from: decoder)
            self.account = try .init(from: decoder)
            
            guard let response = decoder.userInfo[API.JSON.DecoderKey.responseHeader] as? HTTPURLResponse,
                  let headerFields = response.allHeaderFields as? [String:Any],
                  let tokens = Self.Token(headerFields: headerFields) else {
                let errorContext = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "The access token and security token couldn't get extracted from the response header.")
                throw DecodingError.dataCorrupted(errorContext)
            }
            self.tokens = tokens
        }
    }
}

extension API.Session.Certificate {
    /// Representation of a dealing session.
    fileprivate struct Session: Decodable {
        /// Client identifier.
        let client: IG.Client.Identifier
        /// Lightstreamer endpoint for subscribing to account and price updates.
        let streamerURL: URL
        /// Timezone of the active account.
        let timezone: TimeZone
        /// The settings for the current account.
        let settings: API.Session.Settings
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            self.client = try container.decode(IG.Client.Identifier.self, forKey: .client)
            self.streamerURL = try container.decode(URL.self, forKey: .streamerURL)
            let timezoneOffset = try container.decode(Int.self, forKey: .timezoneOffset)
            self.timezone = try TimeZone(secondsFromGMT: timezoneOffset * 3_600) ?! DecodingError.dataCorruptedError(forKey: .timezoneOffset, in: container, debugDescription: "The timezone offset couldn't be migrated to UTC/GMT.")
            self.settings = try .init(from: decoder)
        }
        
        private enum CodingKeys: String, CodingKey {
            case client = "clientId"
            case timezoneOffset
            case streamerURL = "lightstreamerEndpoint"
        }
    }
}

extension API.Session.Certificate {
    /// Information about an account.
    fileprivate struct Account {
        /// Account identifier.
        let identifier: IG.Account.Identifier
        /// Account type.
        let type: API.Account.Kind
        /// The default currency used in this session.
        let currency: IG.Currency.Code
        /// Account balance
        let balance: API.Account.Balance
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.identifier = try container.decode(IG.Account.Identifier.self, forKey: .account)
            self.type = try container.decode(API.Account.Kind.self, forKey: .type)
            self.currency = try container.decode(IG.Currency.Code.self, forKey: .currency)
            self.balance = try container.decode(API.Account.Balance.self, forKey: .balance)
        }
        
        private enum CodingKeys: String, CodingKey {
            case account = "currentAccountId"
            case type = "accountType"
            case currency = "currencyIsoCode"
            case balance = "accountInfo"
        }
    }
}

extension API.Session.Certificate {
    /// Certificate (CST) token with metadata information such as expiration date.
    fileprivate struct Token {
        /// Acess token expiration date.
        let expirationDate: Date
        /// The token actually used on the requests.
        let accessToken: String
        /// Account session security access token.
        let securityToken: String
        /// Designated initializer assigning all values from the given header fields.
        init?(headerFields: [String:Any]) {
            typealias Key = API.HTTP.Header.Key
            
            guard let access = headerFields[Key.clientSessionToken.rawValue] as? String,
                let security = headerFields[Key.securityToken.rawValue] as? String else { return nil }
            self.accessToken = access
            self.securityToken = security
            
            // Default token duration (in seconds): 6 hours
            let timeInterval: TimeInterval = 6 * 60 * 60
            if let dateString = headerFields[Key.date.rawValue] as? String,
                let date = API.Formatter.humanReadableLong.date(from: dateString) {
                self.expirationDate = date.addingTimeInterval(timeInterval)
            } else {
                self.expirationDate = Date(timeIntervalSinceNow: timeInterval)
            }
        }
    }
}

extension API.Session {
    /// Encryption key message returned from the server.
    fileprivate struct EncryptionKey: Decodable {
        /// The key (in base 64) to be used on encryption.
        let encryptionKey: String
        /// Current timestamp in milliseconds since epoch.
        let timeStamp: Date
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.encryptionKey = try container.decode(String.self, forKey: .encryptionKey)
            let epoch = try container.decode(TimeInterval.self, forKey: .timeStamp)
            self.timeStamp = Date(timeIntervalSince1970: epoch * 0.001)
        }
        
        private enum CodingKeys: String, CodingKey {
            case encryptionKey, timeStamp
        }
    }
}

extension API.Session {
    /// Wrapper for the session data and certificate token.
    fileprivate struct WrapperCertificate: Decodable {
        let session: API.Session
        let token: API.Session.Certificate.Token
        
        init(from decoder: Decoder) throws {
            self.session = try .init(from: decoder)
            
            guard let response = decoder.userInfo[API.JSON.DecoderKey.responseHeader] as? HTTPURLResponse,
                  let headerFields = response.allHeaderFields as? [String:Any],
                  let token = API.Session.Certificate.Token(headerFields: headerFields) else {
                let errorContext = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "The access token and security token couldn't get extracted from the response header.")
                throw DecodingError.dataCorrupted(errorContext)
            }
            self.token = token
        }
    }
}
