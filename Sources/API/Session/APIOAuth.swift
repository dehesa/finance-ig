import ReactiveSwift
import Foundation

extension API {
    /// Performs the OAuth login request to the dealing system with the login credential passed as parameter.
    /// - note: No credentials are needed for this endpoint.
    /// - parameter info: OAuth credentials for the IG platform.
    /// - returns: SignalProducer with the new refreshed credentials.
    internal func oauthLogin(_ info: API.Request.Login) -> SignalProducer<API.Credentials,API.Error> {
        return self.makeRequest(.post, "session", version: 3, credentials: false, headers: [.apiKey: info.apiKey, .account:info.accountId], body: {
                let body = ["identifier": info.username, "password": info.password]
                return (.json, try API.Codecs.jsonEncoder().encode(body))
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (r: API.Response.OAuth) in
                let token = API.Credentials.Token(.oauth(access: r.tokens.accessToken, refresh: r.tokens.refreshToken, scope: r.tokens.scope, type: r.tokens.type), expirationDate: r.tokens.expirationDate)
                return API.Credentials(clientId: r.clientId, accountId: r.accountId, apiKey: info.apiKey, token: token, streamerURL: r.streamerURL, timezone: r.timezone)
            }
    }
    
    /// Refreshes a trading session token, obtaining new session for subsequent API.
    /// - note: No credentials are needed for this endpoint.
    /// - parameter credentials: Current platform credentials.
    /// - returns: SignalProducer with the new refreshed credentials.
    internal func oauthRefresh(current credentials: API.Credentials) -> SignalProducer<API.Credentials,API.Error> {
        return self.makeRequest(.post, "session/refresh-token", version: 1, credentials: false, headers: [.apiKey: credentials.apiKey, .account: credentials.accountId], body: {
                guard case .oauth(_, let refreshToken, _, _) = credentials.token.value else {
                    throw API.Error.invalidCredentials(credentials, message: "The credentials stored were not of OAuth type.")
                }

                return (.json, try API.Codecs.jsonEncoder().encode(["refresh_token": refreshToken]))
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .map { (r: API.Response.OAuth.Token) in
                let token = API.Credentials.Token(.oauth(access: r.accessToken, refresh: r.refreshToken, scope: r.scope, type: r.type), expirationDate: r.expirationDate)
                return API.Credentials(credentials, token: token)
            }
    }
}

extension API.Response {
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
        let tokens: OAuth.Token
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let client = try container.decode(String.self, forKey: .clientId)
            self.clientId = try Int(client) ?! DecodingError.dataCorruptedError(forKey: .clientId, in: container, debugDescription: "The clientID \"\(client)\" couldn't be transformed into an integer.")
            
            self.accountId = try container.decode(String.self, forKey: .accountId)
            self.streamerURL = try container.decode(URL.self, forKey: .streamerURL)
            
            let timezoneOffset = try container.decode(Int.self, forKey: .timezoneOffset)
            self.timezone = try TimeZone(secondsFromGMT: timezoneOffset * 3_600) ?! DecodingError.dataCorruptedError(forKey: .timezoneOffset, in: container, debugDescription: "The timezone offset couldn't be migrated to UTC/GMT.")
            
            self.tokens = try container.decode(API.Response.OAuth.Token.self, forKey: .tokens)
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

extension API.Response.OAuth {
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
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.accessToken = try container.decode(String.self, forKey: .accessToken)
            self.refreshToken = try container.decode(String.self, forKey: .refreshToken)
            self.scope = try container.decode(String.self, forKey: .scope)
            self.type = try container.decode(String.self, forKey: .type)
            
            let secondsString = try container.decode(String.self, forKey: .expireInSeconds)
            let seconds = try Double(secondsString) ?! DecodingError.dataCorruptedError(forKey: .expireInSeconds, in: container, debugDescription: "The \"\(CodingKeys.expireInSeconds)\" value (i.e. \(secondsString) could not be transformed into a number.")
            
            if let response = decoder.userInfo[.responseHeader] as? HTTPURLResponse,
               let dateString = response.allHeaderFields[API.HTTP.Header.Key.date] as? String,
               let date = API.DateFormatter.humanReadableLong.date(from: dateString) {
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
