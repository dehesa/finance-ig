import ReactiveSwift
import Foundation

extension API {
    /// Creates a trading session, obtaining session tokens for subsequent API access.
    ///
    /// Region-specific login restrictions may apply.
    /// - note: No credentials are needed for this endpoint.
    /// - parameter info: Certificate credentials for the IG platform.
    /// - parameter isPasswordEncrypted: Boolean indicating whether the given password (in `info`) is encrypted.
    /// - returns: `SignalProducer` that when started it will log in the user passed in the `info` parameter.
    internal func certificateLogin(_ info: API.Request.Login, isPasswordEncrypted: Bool = false) -> SignalProducer<API.Credentials,API.Error> {
        return SignalProducer(api: self) { (_) -> API.Request.Certificate in
                guard !info.username.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Client's username is invalid.")
                }
                guard !info.password.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "Client's password is invalid.")
                }
                guard !info.apiKey.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The API key provided cannot be empty.")
                }
                return .init(identifier: info.username, password: info.password, encryptedPassword: isPasswordEncrypted)
            }.request(.post, "session", version: 2, credentials: false, headers: { (_,_) in [.apiKey: info.apiKey] }, body: { (_, payload) in
                let data = try API.Codecs.jsonEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (r: API.Response.Certificate) in
                let token = API.Credentials.Token(.certificate(access: r.tokens.accessToken, security: r.tokens.securityToken), expirationDate: r.tokens.expirationDate)
                return API.Credentials(clientId: r.clientId, accountId: r.accountId, apiKey: info.apiKey, token: token, streamerURL: r.streamerURL, timezone: r.timezone)
            }
    }
}

// MARK: -

extension API.Request {
    /// Log-in through certificate required payload.
    fileprivate struct Certificate: Encodable {
        /// Client login identifier.
        let identifier: String
        /// Client login password.
        let password: String
        /// Whether the password has been sent encrypted.
        let encryptedPassword: Bool
    }
}

// MARK: -

extension API.Response {
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
        let tokens: Certificate.Token
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let client = try container.decode(String.self, forKey: .clientId)
            self.clientId = try Int(client) ?! DecodingError.dataCorruptedError(forKey: .clientId, in: container, debugDescription: "The clientID \"\(client)\" couldn't be transformed into an integer.")
            
            self.accountId = try container.decode(String.self, forKey: .accountId)
            self.streamerURL = try container.decode(URL.self, forKey: .streamerURL)
            
            let timezoneOffset = try container.decode(Int.self, forKey: .timezoneOffset)
            self.timezone = try TimeZone(secondsFromGMT: timezoneOffset * 3_600) ?! DecodingError.dataCorruptedError(forKey: .timezoneOffset, in: container, debugDescription: "The timezone offset couldn't be migrated to UTC/GMT.")
            
            guard let response = decoder.userInfo[.responseHeader] as? HTTPURLResponse,
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

extension API.Response.Certificate {
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
