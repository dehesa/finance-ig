import ReactiveSwift
import Foundation

extension API.Request.Session {
    
    // MARK: POST /session
    
    /// Performs the OAuth login request to the dealing system with the login credential passed as parameter.
    /// - note: No credentials are needed for this endpoint.
    /// - parameter apiKey: API key given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter user: User name and password to log in into an IG account.
    /// - returns: `SignalProducer` with the new refreshed credentials.
    internal func loginOAuth(apiKey: String, user: API.User) -> SignalProducer<API.Credentials,API.Error> {
        return SignalProducer(api: self.api) { (_) in
                let apiKeyLength = 40
                guard apiKey.utf8.count == apiKeyLength else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The API key provided must be exactly \(apiKeyLength) UTF8 characters. The one provided (\"\(apiKey)\") has \(apiKey.utf8.count) characters.")
                }
            }.request(.post, "session", version: 3, credentials: false, headers: { (_,_) in [.apiKey: apiKey] }, body: { (_,_) in
                let payload = Self.PayloadOAuth(user: user)
                let data = try JSONEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON { (_,responseHeader) -> JSONDecoder in
                return JSONDecoder().set {
                    $0.userInfo[API.JSON.DecoderKey.responseHeader] = responseHeader
                }
            }.map { (r: API.Session.OAuth) in
                let token = API.Credentials.Token(.oauth(access: r.tokens.accessToken, refresh: r.tokens.refreshToken, scope: r.tokens.scope, type: r.tokens.type), expirationDate: r.tokens.expirationDate)
                return API.Credentials(clientId: r.clientId, accountId: r.accountId, apiKey: apiKey, token: token, streamerURL: r.streamerURL, timezone: r.timezone)
            }
    }

    // MARK: POST /session/refresh-token

    /// Refreshes a trading session token, obtaining new session for subsequent API.
    /// - note: No credentials are needed for this endpoint.
    /// - parameter token: The OAuth refresh token (don't confuse it with the OAuth access token).
    /// - parameter apiKey: API key given by the IG platform identifying the usage of the IG endpoints.
    /// - returns: SignalProducer with the new refreshed credentials.
    internal func refreshOAuth(token: String, apiKey: String) -> SignalProducer<API.Credentials.Token,API.Error> {
        return SignalProducer(api: self.api) { (_) -> Self.TemporaryRefresh in
                guard !token.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The OAuth refresh token can't be empty.")
                }
            
                let apiKeyLength = 40
                guard apiKey.utf8.count == apiKeyLength else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The API key provided must be exactly \(apiKeyLength) UTF8 characters. The one provided (\"\(apiKey)\") has \(apiKey.utf8.count) characters.")
                }
            
                return .init(refreshToken: token, apiKey: apiKey)
            }.request(.post, "session/refresh-token", version: 1, credentials: false, headers: { (_, values: TemporaryRefresh) in
                [.apiKey: values.apiKey]
            }, body: { (_, values: TemporaryRefresh) in
                (.json, try JSONEncoder().encode(["refresh_token": values.refreshToken]))
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON { (_,responseHeader) -> JSONDecoder in
                return JSONDecoder().set {
                    $0.userInfo[API.JSON.DecoderKey.responseHeader] = responseHeader
                }
            }.map { (r: API.Session.OAuth.Token) in
                return .init(.oauth(access: r.accessToken, refresh: r.refreshToken, scope: r.scope, type: r.type), expirationDate: r.expirationDate)
            }
    }
}

// MARK: - Supporting Entities

// MARK: Request Entities

extension API.Request.Session {
    private struct PayloadOAuth: Encodable {
        let user: API.User
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Self.CodingKeys.self)
            try container.encode(self.user.name, forKey: .identifier)
            try container.encode(self.user.password, forKey: .password)
        }
        
        private enum CodingKeys: String, CodingKey {
            case identifier, password
        }
    }
    
    private struct TemporaryRefresh {
        let refreshToken: String
        let apiKey: String
    }
}

// MARK: Response Entities

extension API.Session {
    /// Oauth credentials used to access the IG platform.
    fileprivate struct OAuth: Decodable {
        /// Client identifier.
        let clientId: Int
        /// Active account identifier.
        let accountId: String
        /// Lightstreamer endpoint for subscribing to account and price updates.
        let streamerURL: URL
        /// Timezone of the active account.
        let timezone: TimeZone
        /// The OAuth token granting access to the platform
        let tokens: Self.Token
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            let client = try container.decode(String.self, forKey: .clientId)
            self.clientId = try Int(client) ?! DecodingError.dataCorruptedError(forKey: .clientId, in: container, debugDescription: "The clientID \"\(client)\" couldn't be transformed into an integer.")
            
            self.accountId = try container.decode(String.self, forKey: .accountId)
            self.streamerURL = try container.decode(URL.self, forKey: .streamerURL)
            
            /// - bug: The server returns one hour less for the timezone offset.
            let timezoneOffset = (try container.decode(Int.self, forKey: .timezoneOffset)) + 1
            self.timezone = try TimeZone(secondsFromGMT: timezoneOffset * 3_600) ?! DecodingError.dataCorruptedError(forKey: .timezoneOffset, in: container, debugDescription: "The timezone offset couldn't be migrated to UTC/GMT.")
            
            self.tokens = try container.decode(API.Session.OAuth.Token.self, forKey: .tokens)
        }
        
        private enum CodingKeys: String, CodingKey {
            case clientId
            case accountId
            case timezoneOffset
            case streamerURL = "lightstreamerEndpoint"
            case tokens = "oauthToken"
        }
    }
}

extension API.Session.OAuth {
    /// OAuth token with metadata information such as expiration date or refresh token.
    fileprivate struct Token: Decodable {
        /// Acess token expiration date.
        let expirationDate: Date
        /// The token actually used on the requests.
        let accessToken: String
        /// Token used when the `accessToken` has expired, to ask for another one.
        let refreshToken: String
        /// Scope of the access token.
        let scope: String
        /// Token type.
        let type: String
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            self.accessToken = try container.decode(String.self, forKey: .accessToken)
            self.refreshToken = try container.decode(String.self, forKey: .refreshToken)
            self.scope = try container.decode(String.self, forKey: .scope)
            self.type = try container.decode(String.self, forKey: .type)
            
            let secondsString = try container.decode(String.self, forKey: .expireInSeconds)
            let seconds = try TimeInterval(secondsString)
                ?! DecodingError.dataCorruptedError(forKey: .expireInSeconds, in: container, debugDescription: "The \"\(CodingKeys.expireInSeconds)\" value (i.e. \(secondsString) could not be transformed into a number.")
            
            if let response = decoder.userInfo[API.JSON.DecoderKey.responseHeader] as? HTTPURLResponse,
               let dateString = response.allHeaderFields[API.HTTP.Header.Key.date.rawValue] as? String,
               let date = API.TimeFormatter.humanReadableLong.date(from: dateString) {
                self.expirationDate = date.addingTimeInterval(seconds)
            } else {
                self.expirationDate = Date(timeIntervalSinceNow: seconds)
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case scope
            case type = "token_type"
            case expireInSeconds = "expires_in"
        }
    }
}
