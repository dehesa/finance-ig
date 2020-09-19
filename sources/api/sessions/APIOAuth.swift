import Combine
import Conbini
import Foundation

extension API.Request.Session {

    // MARK: POST /session

    /// Performs the OAuth login request with the login credential passed as parameter.
    /// - note: No credentials are needed for this endpoint (i.e. the `API` instance doesn't need to be previously logged in).
    /// - parameter key: API key given by the platform identifying the endpoint usage.
    /// - parameter user: User name and password to log in into an account.
    /// - returns: Publisher forwarding the platform credentials if the login was successful.
    internal func loginOAuth(key: API.Key, user: API.User) -> AnyPublisher<API.Credentials,Swift.Error> {
        self.api.publisher
            .makeRequest(.post, "session", version: 3, credentials: false, headers: { [.apiKey: key.description] }, body: {
                let payload = _PayloadOAuth(user: user)
                return (.json, try JSONEncoder().encode(payload))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(response: true)) { (r: API.Session._OAuth, _) -> API.Credentials in
                let token = API.Token(.oauth(access: r.tokens.accessToken, refresh: r.tokens.refreshToken, scope: r.tokens.scope, type: r.tokens.type), expirationDate: r.tokens.expirationDate)
                return API.Credentials(key: key, client: r.clientId, account: r.accountId, streamerURL: r.streamerURL, timezone: r.timezone, token: token)
            }.eraseToAnyPublisher()
    }

    // MARK: POST /session/refresh-token

    /// Refreshes a trading session token, obtaining new session for subsequent API.
    /// - note: No credentials are needed for this endpoint (i.e. the `API` instance doesn't need to be previously logged in).
    /// - parameter token: The OAuth refresh token (don't confuse it with the OAuth access token).
    /// - parameter key: API key given by the IG platform identifying the usage of the IG endpoints.
    /// - returns: Publisher forwarding the OAUth token if the refresh process was successful.
    internal func refreshOAuth(token: String, key: API.Key) -> AnyPublisher<API.Token,Swift.Error> {
        self.api.publisher { _ -> _TemporaryRefresh in
                guard !token.isEmpty else { throw IG.Error._emptyRefreshToken(key: key) }
                return _TemporaryRefresh(refreshToken: token, apiKey: key)
            }.makeRequest(.post, "session/refresh-token", version: 1, credentials: false, headers: { [.apiKey: $0.apiKey.description] }, body: {
                let payload = ["refresh_token": $0.refreshToken]
                return (.json, try JSONEncoder().encode(payload))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(response: true)) { (r: API.Session._OAuth._Token, _) in
                .init(.oauth(access: r.accessToken, refresh: r.refreshToken, scope: r.scope, type: r.type), expirationDate: r.expirationDate)
            }.eraseToAnyPublisher()
    }
}

// MARK: - Request Entities

private extension API.Request.Session {
    struct _PayloadOAuth: Encodable {
        let user: API.User
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: _Keys.self)
            try container.encode(self.user.name, forKey: .identifier)
            try container.encode(self.user.password, forKey: .password)
        }
        
        private enum _Keys: String, CodingKey {
            case identifier, password
        }
    }
    
    struct _TemporaryRefresh {
        let refreshToken: String
        let apiKey: API.Key
    }
}

// MARK: Response Entities

fileprivate extension API.Session {
    /// Oauth credentials used to access the IG platform.
    struct _OAuth: Decodable {
        /// Client identifier.
        let clientId: IG.Client.Identifier
        /// Active account identifier.
        let accountId: IG.Account.Identifier
        /// Lightstreamer endpoint for subscribing to account and price updates.
        let streamerURL: URL
        /// Timezone of the active account.
        let timezone: TimeZone
        /// The OAuth token granting access to the platform
        let tokens: _Token
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: _Keys.self)
            self.clientId = try container.decode(IG.Client.Identifier.self, forKey: .clientId)
            self.accountId = try container.decode(IG.Account.Identifier.self, forKey: .accountId)
            self.streamerURL = try container.decode(URL.self, forKey: .streamerURL)
            // - warning: The OAuth login doesn't account for summer/winter time. However the certificate and getSession do.
            let timezoneOffset = try container.decode(Int.self, forKey: .timezoneOffset) + 1
            self.timezone = try TimeZone(secondsFromGMT: timezoneOffset * 3_600) ?> DecodingError.dataCorruptedError(forKey: .timezoneOffset, in: container, debugDescription: "The timezone offset couldn't be migrated to UTC/GMT")
            
            self.tokens = try container.decode(API.Session._OAuth._Token.self, forKey: .tokens)
        }
        
        private enum _Keys: String, CodingKey {
            case clientId
            case accountId
            case timezoneOffset
            case streamerURL = "lightstreamerEndpoint"
            case tokens = "oauthToken"
        }
    }
}

fileprivate extension API.Session._OAuth {
    /// OAuth token with metadata information such as expiration date or refresh token.
    struct _Token: Decodable {
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
            let container = try decoder.container(keyedBy: _Keys.self)
            
            self.accessToken = try container.decode(String.self, forKey: .accessToken)
            self.refreshToken = try container.decode(String.self, forKey: .refreshToken)
            self.scope = try container.decode(String.self, forKey: .scope)
            self.type = try container.decode(String.self, forKey: .type)
            
            let secondsString = try container.decode(String.self, forKey: .expireInSeconds)
            let seconds = try TimeInterval(secondsString)
                ?> DecodingError.dataCorruptedError(forKey: .expireInSeconds, in: container, debugDescription: "The '\(_Keys.expireInSeconds)' value (i.e. \(secondsString) could not be transformed into a number")
            
            if let response = decoder.userInfo[API.JSON.DecoderKey.responseHeader] as? HTTPURLResponse,
               let dateString = response.allHeaderFields[API.HTTP.Header.Key.date.rawValue] as? String,
               let date = DateFormatter.humanReadableLong.date(from: dateString) {
                self.expirationDate = date.addingTimeInterval(seconds)
            } else {
                self.expirationDate = Date(timeIntervalSinceNow: seconds)
            }
        }
        
        private enum _Keys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case scope
            case type = "token_type"
            case expireInSeconds = "expires_in"
        }
    }
}

private extension IG.Error {
    /// Error raised when OAuth refresh token is empty.
    static func _emptyRefreshToken(key: API.Key) -> Self {
        Self(.api(.invalidRequest), "The OAuth refresh token cannot be empty.", help: "Read the request documentation and be sure to follow all requirements.", info: ["API key": key])
    }
}
