import ReactiveSwift
import Foundation

extension API.Request.Session {
    
    // MARK: POST /session

    /// Creates a trading session, obtaining session tokens for subsequent API access.
    ///
    /// Region-specific login restrictions may apply.
    /// - note: No credentials are needed for this endpoint.
    /// - todo: Password encryption doesn't work! Currently it is ignoring the parameter.
    /// - parameter apiKey: API key given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter user: User name and password to log in into an IG account.
    /// - parameter encryptPassword: Boolean indicating whether the given password shall be encrypted before sending it to the server.
    /// - returns: `SignalProducer` that when started it will log in the user passed in the `info` parameter.
    internal func loginCertificate(apiKey: String, user: (name: String, password: String), encryptPassword: Bool = false) -> SignalProducer<API.Credentials,API.Error> {
        return SignalProducer(api: self.api) { (_) -> Self.PayloadCertificate in
                let apiKeyLength: Int = 40
                guard apiKey.utf8.count == apiKeyLength else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The API key provided must be exactly \(apiKeyLength) UTF8 characters. The one provided (\"\(apiKey)\") has \(apiKey.utf8.count) characters.")
                }
            
                guard !user.name.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Client's username is invalid.")
                }
                guard !user.password.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Client's password is invalid.")
                }
            
                return .init(identifier: user.name, password: user.password, encryptedPassword: false)
            }.request(.post, "session", version: 2, credentials: false, headers: { (_,_) in [.apiKey: apiKey] }, body: { (_, payload) in
                let data = try JSONEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON(with: { (request, responseHeader) -> JSONDecoder in
                let decoder = JSONDecoder()
                decoder.userInfo[API.JSON.DecoderKey.responseHeader] = responseHeader
                return decoder
            })
            .map { (r: API.Session.Certificate) in
                let token = API.Credentials.Token(.certificate(access: r.tokens.accessToken, security: r.tokens.securityToken), expirationDate: r.tokens.expirationDate)
                return API.Credentials(clientId: r.clientId, accountId: r.accountId, apiKey: apiKey, token: token, streamerURL: r.streamerURL, timezone: r.timezone)
            }
    }
    
    // MARK: GET /session/encryptionKey
    
    /// Returns an encryption key to use in order to send the user password in an encrypted form.
    /// - parameter apiKey: The API key which the encryption key will be associated to.
    /// - returns: `SignalProducer` returning the session's encryption key with the key's timestamp.
    /// - note: No credentials are needed for this endpoint.
    fileprivate func generateEncryptionKey(apiKey: String) -> SignalProducer<API.Session.EncryptionKey,API.Error> {
        return SignalProducer(api: self.api) { (_) -> String in
            guard !apiKey.isEmpty else {
                throw API.Error.invalidRequest(underlyingError: nil, message: "The API key provided cannot be empty.")
            }
            return apiKey
        }.request(.get, "session/encryptionKey", version: 1, credentials: false, headers: { (_,key) in [.apiKey: key] })
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
        let identifier: String
        let password: String
        let encryptedPassword: Bool
    }
}

// MARK: Response Entities

extension API.Session {
    /// CST credentials used to access the IG platform.
    fileprivate struct Certificate: Decodable {
        /// Client identifier.
        let clientId: Int
        /// Active account identifier.
        let accountId: String
        /// Lightstreamer endpoint for subscribing to account and price updates.
        let streamerURL: URL
        /// Timezone of the active account.
        let timezone: TimeZone
        /// The certificate tokens granting access to the platform.
        let tokens: Self.Token
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            let client = try container.decode(String.self, forKey: .clientId)
            self.clientId = try Int(client) ?! DecodingError.dataCorruptedError(forKey: .clientId, in: container, debugDescription: "The clientID \"\(client)\" couldn't be transformed into an integer.")
            
            self.accountId = try container.decode(String.self, forKey: .accountId)
            self.streamerURL = try container.decode(URL.self, forKey: .streamerURL)
            
            let timezoneOffset = try container.decode(Int.self, forKey: .timezoneOffset)
            self.timezone = try TimeZone(secondsFromGMT: timezoneOffset * 3_600) ?! DecodingError.dataCorruptedError(forKey: .timezoneOffset, in: container, debugDescription: "The timezone offset couldn't be migrated to UTC/GMT.")
            
            guard let response = decoder.userInfo[API.JSON.DecoderKey.responseHeader] as? HTTPURLResponse,
                  let headerFields = response.allHeaderFields as? [String:Any],
                  let tokens = Token(headerFields: headerFields) else {
                let errorContext = DecodingError.Context(codingPath: container.codingPath, debugDescription: "The access token and security token couldn't get extracted from the response header.")
                throw DecodingError.dataCorrupted(errorContext)
            }
            self.tokens = tokens
        }
        
        private enum CodingKeys: String, CodingKey {
            case clientId
            case accountId = "currentAccountId"
            case timezoneOffset
            case streamerURL = "lightstreamerEndpoint"
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
        
        init?(headerFields: [String:Any]) {
            guard let access = headerFields[API.HTTP.Header.Key.clientSessionToken.rawValue] as? String,
                  let security = headerFields[API.HTTP.Header.Key.securityToken.rawValue] as? String else { return nil }
            self.accessToken = access
            self.securityToken = security
            
            // Default token duration (in seconds): 6 hours
            let timeInterval: TimeInterval = 6 * 60 * 60
            if let dateString = headerFields[API.HTTP.Header.Key.date.rawValue] as? String,
               let date = API.DateFormatter.humanReadableLong.date(from: dateString) {
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
            let epoch = try container.decode(Double.self, forKey: .timeStamp)
            self.timeStamp = Date(timeIntervalSince1970: epoch * 0.001)
        }
        
        private enum CodingKeys: String, CodingKey {
            case encryptionKey, timeStamp
        }
    }
}
