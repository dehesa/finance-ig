import Combine
import Foundation

extension IG.API.Request.Session {

    // MARK: POST /session

    /// Creates a trading session, obtaining session tokens for subsequent API access.
    ///
    /// Region-specific login restrictions may apply.
    /// - note: No credentials are needed for this endpoint.
    /// - todo: Password encryption doesn't work! Currently it is ignoring the parameter.
    /// - parameter key: API key given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter user: User name and password to log in into an IG account.
    /// - parameter encryptPassword: Boolean indicating whether the given password shall be encrypted before sending it to the server.
    /// - returns: `Future` related type forwarding platform credentials if the login was successful.
    internal func loginCertificate(key: IG.API.Key, user: IG.API.User, encryptPassword: Bool = false) -> IG.API.Publishers.Decode<Void,(credentials: IG.API.Credentials, settings: IG.API.Session.Settings)> {
        self.api.publisher
            .makeRequest(.post, "session", version: 2, credentials: false, headers: { [.apiKey: key.rawValue] }, body: {
                let payload = Self.PayloadCertificate(user: user, encryptedPassword: encryptPassword)
                return (.json, try JSONEncoder().encode(payload))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(response: true)) { (r: IG.API.Session.Certificate, _) in
                let token = IG.API.Credentials.Token(.certificate(access: r.tokens.accessToken, security: r.tokens.securityToken), expirationDate: r.tokens.expirationDate)
                let credentials = IG.API.Credentials(client: r.session.client, account: r.account.identifier, key: key, token: token, streamerURL: r.session.streamerURL, timezone: r.session.timezone)
                return (credentials, r.session.settings)
            }
    }

    // MARK: GET /session?fetchSessionTokens=true

    /// It regenerates certificate credentials from the current session (whether OAuth or Certificate logged in).
    /// - returns: `Future` related type forwarding a `IG.API.Credentials.Token.certificate` if the process was successful.
    internal func refreshCertificate() -> AnyPublisher<IG.API.Credentials.Token,Swift.Error> {
        self.api.publisher
            .makeRequest(.get, "session", version: 1, credentials: true, queries: { [URLQueryItem(name: "fetchSessionTokens", value: "true")] })
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(response: true)) { (r: IG.API.Session.WrapperCertificate, _) in
                .init(.certificate(access: r.token.accessToken, security: r.token.securityToken), expirationDate: r.token.expirationDate)
            }.eraseToAnyPublisher()
    }

    /// Returns the user's session details for the credentials given as arguments and regenerates the certificate tokens.
    /// - note: No credentials (besides the provided ones as parameter) are needed for this endpoint.
    /// - parameter key: API key given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter token: The credentials for the user session to query.
    /// - returns: `Future` related type forwarding a `IG.API.Credentials.Token.certificate` if the process was successful.
    internal func refreshCertificate(key: IG.API.Key, token: IG.API.Credentials.Token) -> AnyPublisher<(IG.API.Session,IG.API.Credentials.Token),IG.API.Error> {
        self.api.publisher
            .makeRequest(.get, "session", version: 1, credentials: false, queries: { [URLQueryItem(name: "fetchSessionTokens", value: "true")] }, headers: {
                var result = [IG.API.HTTP.Header.Key.apiKey: key.rawValue]
                switch token.value {
                case .certificate(let access, let security):
                    result[.clientSessionToken] = access
                    result[.securityToken] = security
                case .oauth(let access, _, _, let type):
                    result[.authorization] = "\(type) \(access)"
                }
                return result
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(response: true)) { (r: IG.API.Session.WrapperCertificate, _) in
                let token = IG.API.Credentials.Token(.certificate(access: r.token.accessToken, security: r.token.securityToken), expirationDate: r.token.expirationDate)
                return (r.session, token)
            }.mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }

    // MARK: GET /session/encryptionKey

    /// Returns an encryption key to use in order to send the user password in an encrypted form.
    ///
    /// To encrypt a password:
    /// 1. call /session/encryptionKey which gives a key and timestamp
    /// 2. create a RSA token using the key.
    /// 3. encrypt password + "|" + timestamp
    /// - note: No credentials are needed for this endpoint.
    /// - parameter key: The API key which the encryption key will be associated to.
    /// - returns: `Future` related type forwarding the session's encryption key with the key's timestamp.
    fileprivate func generateEncryptionKey(key: IG.API.Key) -> AnyPublisher<IG.API.Session.EncryptionKey,IG.API.Error> {
        self.api.publisher
            .makeRequest(.get, "session/encryptionKey", version: 1, credentials: false, headers: { [.apiKey: key.rawValue] })
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension IG.API.Request.Session {
    /// Log-in through certificate required payload.
    private struct PayloadCertificate: Encodable {
        let user: IG.API.User
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

extension IG.API.Session {
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
            
            guard let response = decoder.userInfo[IG.API.JSON.DecoderKey.responseHeader] as? HTTPURLResponse,
                  let headerFields = response.allHeaderFields as? [String:Any],
                  let tokens = Self.Token(headerFields: headerFields) else {
                let errorContext = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "The access token and security token couldn't get extracted from the response header")
                throw DecodingError.dataCorrupted(errorContext)
            }
            self.tokens = tokens
        }
    }
}

extension IG.API.Session.Certificate {
    /// Representation of a dealing session.
    fileprivate struct Session: Decodable {
        /// Client identifier.
        let client: IG.Client.Identifier
        /// Lightstreamer endpoint for subscribing to account and price updates.
        let streamerURL: URL
        /// Timezone of the active account.
        let timezone: TimeZone
        /// The settings for the current account.
        let settings: IG.API.Session.Settings
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            self.client = try container.decode(IG.Client.Identifier.self, forKey: .client)
            self.streamerURL = try container.decode(URL.self, forKey: .streamerURL)
            let timezoneOffset = try container.decode(Int.self, forKey: .timezoneOffset)
            self.timezone = try TimeZone(secondsFromGMT: timezoneOffset * 3_600) ?! DecodingError.dataCorruptedError(forKey: .timezoneOffset, in: container, debugDescription: "The timezone offset couldn't be migrated to UTC/GMT")
            self.settings = try .init(from: decoder)
        }
        
        private enum CodingKeys: String, CodingKey {
            case client = "clientId"
            case timezoneOffset
            case streamerURL = "lightstreamerEndpoint"
        }
    }
}

extension IG.API.Session.Certificate {
    /// Information about an account.
    fileprivate struct Account {
        /// Account identifier.
        let identifier: IG.Account.Identifier
        /// Account type.
        let type: IG.API.Account.Kind
        /// The default currency used in this session.
        let currencyCode: IG.Currency.Code
        /// Account balance
        let balance: IG.API.Account.Balance
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.identifier = try container.decode(IG.Account.Identifier.self, forKey: .account)
            self.type = try container.decode(IG.API.Account.Kind.self, forKey: .type)
            self.currencyCode = try container.decode(IG.Currency.Code.self, forKey: .currencyCode)
            self.balance = try container.decode(IG.API.Account.Balance.self, forKey: .balance)
        }
        
        private enum CodingKeys: String, CodingKey {
            case account = "currentAccountId"
            case type = "accountType"
            case currencyCode = "currencyIsoCode"
            case balance = "accountInfo"
        }
    }
}

extension IG.API.Session.Certificate {
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
            typealias Key = IG.API.HTTP.Header.Key
            
            guard let access = headerFields[Key.clientSessionToken.rawValue] as? String,
                let security = headerFields[Key.securityToken.rawValue] as? String else { return nil }
            self.accessToken = access
            self.securityToken = security
            
            // Default token duration (in seconds): 6 hours
            let timeInterval: TimeInterval = 6 * 60 * 60
            if let dateString = headerFields[Key.date.rawValue] as? String,
                let date = IG.API.Formatter.humanReadableLong.date(from: dateString) {
                self.expirationDate = date.addingTimeInterval(timeInterval)
            } else {
                self.expirationDate = Date(timeIntervalSinceNow: timeInterval)
            }
        }
    }
}

extension IG.API.Session {
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

extension IG.API.Session {
    /// Wrapper for the session data and certificate token.
    fileprivate struct WrapperCertificate: Decodable {
        let session: IG.API.Session
        let token: IG.API.Session.Certificate.Token
        
        init(from decoder: Decoder) throws {
            self.session = try .init(from: decoder)
            
            guard let response = decoder.userInfo[IG.API.JSON.DecoderKey.responseHeader] as? HTTPURLResponse,
                  let headerFields = response.allHeaderFields as? [String:Any],
                  let token = IG.API.Session.Certificate.Token(headerFields: headerFields) else {
                let errorContext = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "The access token and security token couldn't get extracted from the response header")
                throw DecodingError.dataCorrupted(errorContext)
            }
            self.token = token
        }
    }
}
