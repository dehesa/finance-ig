import Combine
import Conbini
import Foundation

extension API.Request.Session {

    // MARK: POST /session

    /// Creates a trading session, obtaining session tokens for subsequent API access.
    ///
    /// Region-specific login restrictions may apply.
    /// - note: No credentials are needed for this endpoint (i.e. the `API` instance doesn't need to be previously logged in).
    /// - todo: Password encryption doesn't work! Currently it is ignoring the parameter.
    /// - parameter key: API key given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter user: User name and password to log in into an IG account.
    /// - parameter encryptPassword: Boolean indicating whether the given password shall be encrypted before sending it to the server.
    /// - returns: `Future` related type forwarding platform credentials if the login was successful.
    internal func loginCertificate(key: API.Key, user: API.User, encryptPassword: Bool = false) -> AnyPublisher<(credentials: API.Credentials, settings: API.Session.Settings), Swift.Error> {
        self.api.publisher
            .makeRequest(.post, "session", version: 2, credentials: false, headers: { [.apiKey: key.description] }, body: {
                let payload = _PayloadCertificate(user: user, encryptedPassword: encryptPassword)
                return (.json, try JSONEncoder().encode(payload))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(response: true)) { (r: API.Session._Certificate, _) -> (credentials: API.Credentials, settings: API.Session.Settings) in
                let token = API.Token(.certificate(access: r.tokens.accessToken, security: r.tokens.securityToken), expirationDate: r.tokens.expirationDate)
                let credentials = API.Credentials(key: key, client: r.session.client, account: r.account.id, streamerURL: r.session.streamerURL, timezone: r.session.timezone, token: token)
                return (credentials, r.session.settings)
            }.eraseToAnyPublisher()
    }

    // MARK: GET /session?fetchSessionTokens=true

    /// It regenerates certificate credentials from the current session (whether OAuth or Certificate logged in).
    /// - returns: Future related type forwarding a `API.Credentials.Token.certificate` if the process was successful.
    internal func refreshCertificate() -> AnyPublisher<API.Token,Swift.Error> {
        self.api.publisher
            .makeRequest(.get, "session", version: 1, credentials: true, queries: { [URLQueryItem(name: "fetchSessionTokens", value: "true")] })
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(response: true)) { (r: API.Session._WrapperCertificate, _) in
                .init(.certificate(access: r.token.accessToken, security: r.token.securityToken), expirationDate: r.token.expirationDate)
            }.eraseToAnyPublisher()
    }

    /// Returns the user's session details for the credentials given as arguments and regenerates the certificate tokens.
    /// - note: No credentials (besides the provided ones as parameter) are needed for this endpoint (i.e. the `API` instance doesn't need to be previously logged in).
    /// - parameter key: API key given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter token: The credentials for the user session to query.
    /// - returns: *Future* forwarding a `API.Credentials.Token.certificate` if the process was successful.
    internal func refreshCertificate(key: API.Key, token: API.Token) -> AnyPublisher<(API.Session,API.Token),IG.Error> {
        self.api.publisher
            .makeRequest(.get, "session", version: 1, credentials: false, queries: { [URLQueryItem(name: "fetchSessionTokens", value: "true")] }, headers: {
                var result = [API.HTTP.Header.Key.apiKey: key.description]
                switch token.value {
                case .certificate(let access, let security):
                    result[.clientSessionToken] = access
                    result[.securityToken] = security
                case .oauth(let access, _, _, let type):
                    result[.authorization] = "\(type) \(access)"
                }
                return result
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(response: true)) { (r: API.Session._WrapperCertificate, _) in
                let token = API.Token(.certificate(access: r.token.accessToken, security: r.token.securityToken), expirationDate: r.token.expirationDate)
                return (r.session, token)
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }

    // MARK: GET /session/encryptionKey

    /// Returns an encryption key to use in order to send the user password in an encrypted form.
    ///
    /// To encrypt a password:
    /// 1. call this endpoint which gives a key and timestamp
    /// 2. create a RSA token using the key.
    /// 3. encrypt password + `|` + timestamp
    /// - note: No credentials are needed for this endpoint (i.e. the `API` instance doesn't need to be previously logged in).
    /// - parameter key: The API key which the encryption key will be associated to.
    /// - returns: *Future* forwarding the session's encryption key with the key's timestamp.
    /// - todo: Use this to encrypt the password.
    fileprivate func _generateEncryptionKey(key: API.Key) -> AnyPublisher<API.Session._EncryptionKey,IG.Error> {
        self.api.publisher
            .makeRequest(.get, "session/encryptionKey", version: 1, credentials: false, headers: { [.apiKey: key.description] })
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

// MARK: - Request Entities

private extension API.Request.Session {
    /// Log-in through certificate required payload.
    struct _PayloadCertificate: Encodable {
        let user: API.User
        let encryptedPassword: Bool
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: _CodingKeys.self)
            try container.encode(self.user.name, forKey: .identifier)
            try container.encode(self.user.password, forKey: .password)
            try container.encode(self.encryptedPassword, forKey: .encryptedPassword)
        }
        
        private enum _CodingKeys: String, CodingKey {
            case identifier, password, encryptedPassword
        }
    }
}

// Response Entities

fileprivate extension API.Session {
    /// CST credentials used to access the IG platform.
    struct _Certificate: Decodable {
        /// Logged session
        let session: _Session
        /// Active account identifier.
        let account: _Account
        /// The certificate tokens granting access to the platform.
        let tokens: _Token
        
        init(from decoder: Decoder) throws {
            self.session = try .init(from: decoder)
            self.account = try .init(from: decoder)
            
            guard let response = decoder.userInfo[API.JSON.DecoderKey.responseHeader] as? HTTPURLResponse,
                  let headerFields = response.allHeaderFields as? [String:Any],
                  let tokens = _Token(headerFields: headerFields) else {
                let errorContext = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "The access token and security token couldn't get extracted from the response header")
                throw DecodingError.dataCorrupted(errorContext)
            }
            self.tokens = tokens
        }
    }
}

fileprivate extension API.Session._Certificate {
    /// Representation of a dealing session.
    struct _Session: Decodable {
        /// Client identifier.
        let client: IG.Client.Identifier
        /// Lightstreamer endpoint for subscribing to account and price updates.
        let streamerURL: URL
        /// Timezone of the active account.
        let timezone: TimeZone
        /// The settings for the current account.
        let settings: API.Session.Settings
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: _Keys.self)
            
            self.client = try container.decode(IG.Client.Identifier.self, forKey: .client)
            self.streamerURL = try container.decode(URL.self, forKey: .streamerURL)
            let timezoneOffset = try container.decode(Int.self, forKey: .timezoneOffset)
            self.timezone = try TimeZone(secondsFromGMT: timezoneOffset * 3_600) ?> DecodingError.dataCorruptedError(forKey: .timezoneOffset, in: container, debugDescription: "The timezone offset couldn't be migrated to UTC/GMT")
            self.settings = try .init(from: decoder)
        }
        
        private enum _Keys: String, CodingKey {
            case client = "clientId"
            case timezoneOffset
            case streamerURL = "lightstreamerEndpoint"
        }
    }
}

fileprivate extension API.Session._Certificate {
    /// Information about an account.
    struct _Account: Identifiable {
        /// Account identifier.
        let id: IG.Account.Identifier
        /// Account type.
        let type: API.Account.Kind
        /// The default currency used in this session.
        let currency: Currency.Code
        /// Account balance
        let balance: API.Account.Balance
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: _Keys.self)
            self.id = try container.decode(IG.Account.Identifier.self, forKey: .account)
            self.type = try container.decode(API.Account.Kind.self, forKey: .type)
            self.currency = try container.decode(Currency.Code.self, forKey: .currency)
            self.balance = try container.decode(API.Account.Balance.self, forKey: .balance)
        }
        
        private enum _Keys: String, CodingKey {
            case account = "currentAccountId"
            case type = "accountType"
            case currency = "currencyIsoCode"
            case balance = "accountInfo"
        }
    }
}

fileprivate extension API.Session._Certificate {
    /// Certificate (CST) token with metadata information such as expiration date.
    struct _Token {
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
                let date = DateFormatter.humanReadableLong.date(from: dateString) {
                self.expirationDate = date.addingTimeInterval(timeInterval)
            } else {
                self.expirationDate = Date(timeIntervalSinceNow: timeInterval)
            }
        }
    }
}

fileprivate extension API.Session {
    /// Encryption key message returned from the server.
    struct _EncryptionKey: Decodable {
        /// The key (in base 64) to be used on encryption.
        let encryptionKey: String
        /// Current timestamp in milliseconds since epoch.
        let timeStamp: Date
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: _Keys.self)
            self.encryptionKey = try container.decode(String.self, forKey: .encryptionKey)
            let epoch = try container.decode(TimeInterval.self, forKey: .timeStamp)
            self.timeStamp = Date(timeIntervalSince1970: epoch * 0.001)
        }
        
        private enum _Keys: String, CodingKey {
            case encryptionKey, timeStamp
        }
    }
}

fileprivate extension API.Session {
    /// Wrapper for the session data and certificate token.
    struct _WrapperCertificate: Decodable {
        let session: API.Session
        let token: API.Session._Certificate._Token
        
        init(from decoder: Decoder) throws {
            self.session = try .init(from: decoder)
            
            guard let response = decoder.userInfo[API.JSON.DecoderKey.responseHeader] as? HTTPURLResponse,
                  let headerFields = response.allHeaderFields as? [String:Any],
                  let token = API.Session._Certificate._Token(headerFields: headerFields) else {
                let errorContext = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "The access token and security token couldn't get extracted from the response header")
                throw DecodingError.dataCorrupted(errorContext)
            }
            self.token = token
        }
    }
}
