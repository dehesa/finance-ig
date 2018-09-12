import Utils
import ReactiveSwift
import Result
import Foundation

extension API {
    /// Creates a trading session, obtaining session tokens for subsequent API access.
    ///
    /// Region-specific login restrictions may apply.
    /// - note: No credentials are needed for this endpoint.
    internal func certificateLogin(_ info: API.Request.Login) -> SignalProducer<API.Credentials,API.Error> {
        return self.makeRequest(.post, "session", version: 2, credentials: false, headers: [.apiKey: info.apiKey], body: {
                let body = ["identifier": info.username, "password": info.password, "encryptedPassword": nil]
                return (.json, try API.Codecs.jsonEncoder().encode(body))
          }).send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
            .attemptMap { (r: API.Response.Certificate) in
                return Result<API.Credentials,API.Error> {
                    let clientID = try Int(r.clientId) ?! API.Error.invalidCredentials(nil, message: "The clientID \"\(r.clientId)\" couldn't be transformed into an integer.")
                    let timezone = try TimeZone(secondsFromGMT: r.timezoneOffset * 3_600) ?! API.Error.invalidCredentials(nil, message: "The timezone offset couldn't be migrated to UTC/GMT.")
                    let token = API.Credentials.Token(.certificate(access: r.tokens.accessToken, security: r.tokens.securityToken), expirationDate: r.tokens.expirationDate)
                    return API.Credentials(clientId: clientID, accountId: r.accountId, apiKey: info.apiKey, token: token, streamerURL: r.streamerURL, timezone: timezone)
                }
            }
    }
}

extension API.Response {
    /// CST credentials used to access the IG platform.
    fileprivate struct Certificate: APIResponseLogin, Decodable {
        let clientId: String
        let accountId: String
        let streamerURL: URL
        let timezoneOffset: Int
        /// The certificate tokens granting access to the platform.
        let tokens: Certificate.Token
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.clientId = try container.decode(String.self, forKey: .clientId)
            self.accountId = try container.decode(String.self, forKey: .accountId)
            self.timezoneOffset = try container.decode(Int.self, forKey: .timezoneOffset)
            self.streamerURL = try container.decode(URL.self, forKey: .streamerURL)
            
            guard let response = decoder.userInfo[.responseHeader] as? HTTPURLResponse,
                  let headerFields = response.allHeaderFields as? [String:Any],
                  let tokens = Token(headerFields: headerFields) else {
                let context = DecodingError.Context(codingPath: container.codingPath, debugDescription: "The access token and security token couldn't get extracted from the response header.")
                throw DecodingError.dataCorrupted(context)
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
        
        fileprivate init?(headerFields: [String:Any]) {
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
