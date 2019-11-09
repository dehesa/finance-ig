import Combine
import Foundation

extension IG.API.Request.Session {

    // MARK: POST /session

    /// Performs the OAuth login request with the login credential passed as parameter.
    /// - note: No credentials are needed for this endpoint (i.e. the `API` instance doesn't need to be previously logged in).
    /// - parameter key: API key given by the platform identifying the endpoint usage.
    /// - parameter user: User name and password to log in into an account.
    /// - returns: `Future` related type forwarding the platform credentials if the login was successful.
    internal func loginOAuth(key: IG.API.Key, user: IG.API.User) -> AnyPublisher<IG.API.Credentials,Swift.Error> {
        self.api.publisher
            .makeRequest(.post, "session", version: 3, credentials: false, headers: { [.apiKey: key.rawValue] }, body: {
                let payload = Self.PayloadOAuth(user: user)
                return (.json, try JSONEncoder().encode(payload))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(response: true)) { (r: IG.API.Session.OAuth, _) -> IG.API.Credentials in
                let token = IG.API.Token(.oauth(access: r.tokens.accessToken, refresh: r.tokens.refreshToken, scope: r.tokens.scope, type: r.tokens.type), expirationDate: r.tokens.expirationDate)
                return .init(client: r.clientId, account: r.accountId, key: key, token: token, streamerURL: r.streamerURL, timezone: r.timezone)
            }.eraseToAnyPublisher()
    }

    // MARK: POST /session/refresh-token

    /// Refreshes a trading session token, obtaining new session for subsequent API.
    /// - note: No credentials are needed for this endpoint (i.e. the `API` instance doesn't need to be previously logged in).
    /// - parameter token: The OAuth refresh token (don't confuse it with the OAuth access token).
    /// - parameter key: API key given by the IG platform identifying the usage of the IG endpoints.
    /// - returns: `Future` related type forwarding the OAUth token if the refresh process was successful.
    internal func refreshOAuth(token: String, key: IG.API.Key) -> AnyPublisher<IG.API.Token,Swift.Error> {
        self.api.publisher { _ -> Self.TemporaryRefresh in
                guard !token.isEmpty else { throw IG.API.Error.invalidRequest("The OAuth refresh token cannot be empty", suggestion: .readDocs) }
                return Self.TemporaryRefresh(refreshToken: token, apiKey: key)
            }.makeRequest(.post, "session/refresh-token", version: 1, credentials: false, headers: { [.apiKey: $0.apiKey.rawValue] }, body: {
                let payload = ["refresh_token": $0.refreshToken]
                return (.json, try JSONEncoder().encode(payload))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(response: true)) { (r: IG.API.Session.OAuth.Token, _) in
                .init(.oauth(access: r.accessToken, refresh: r.refreshToken, scope: r.scope, type: r.type), expirationDate: r.expirationDate)
            }.eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension IG.API.Request.Session {
    private struct PayloadOAuth: Encodable {
        let user: IG.API.User
        
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
        let apiKey: IG.API.Key
    }
}

// MARK: Response Entities

extension IG.API.Session {
    /// Oauth credentials used to access the IG platform.
    fileprivate struct OAuth: Decodable {
        /// Client identifier.
        let clientId: IG.Client.Identifier
        /// Active account identifier.
        let accountId: IG.Account.Identifier
        /// Lightstreamer endpoint for subscribing to account and price updates.
        let streamerURL: URL
        /// Timezone of the active account.
        let timezone: TimeZone
        /// The OAuth token granting access to the platform
        let tokens: Self.Token
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.clientId = try container.decode(IG.Client.Identifier.self, forKey: .clientId)
            self.accountId = try container.decode(IG.Account.Identifier.self, forKey: .accountId)
            self.streamerURL = try container.decode(URL.self, forKey: .streamerURL)
            let timezoneOffset = (try container.decode(Int.self, forKey: .timezoneOffset))
            self.timezone = try TimeZone(secondsFromGMT: timezoneOffset * 3_600) ?! DecodingError.dataCorruptedError(forKey: .timezoneOffset, in: container, debugDescription: "The timezone offset couldn't be migrated to UTC/GMT")
            
            self.tokens = try container.decode(IG.API.Session.OAuth.Token.self, forKey: .tokens)
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

extension IG.API.Session.OAuth {
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
                ?! DecodingError.dataCorruptedError(forKey: .expireInSeconds, in: container, debugDescription: "The \"\(CodingKeys.expireInSeconds)\" value (i.e. \(secondsString) could not be transformed into a number")
            
            if let response = decoder.userInfo[IG.API.JSON.DecoderKey.responseHeader] as? HTTPURLResponse,
               let dateString = response.allHeaderFields[IG.API.HTTP.Header.Key.date.rawValue] as? String,
               let date = IG.API.Formatter.humanReadableLong.date(from: dateString) {
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
