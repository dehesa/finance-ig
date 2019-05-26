import ReactiveSwift
import Foundation

extension API {
    /// Creates a trading session, obtaining session tokens for subsequent API access.
    /// - parameter apiKey: The API key which the encryption key will be associated to.
    /// - returns: `SignalProducer` returning the session's encryption key with the key's timestamp.
    /// - note: No credentials are needed for this endpoint.
    public func sessionEncryptionKey(apiKey: String) -> SignalProducer<API.Response.Session.EncryptionKey,API.Error> {
        return self.makeRequest(.get, "session/encryptionKey", version: 1, credentials: false, headers: [.apiKey: apiKey])
            .send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
    }
    
    /// Logs in a user/account.
    /// - parameter info: LogIn credentials for the platform.
    /// - parameter type: The type of session the user want to perform.
    /// - returns: `SignalProducer` returning `type` credentials to use priviledge API endpoints.
    /// - note: No credentials are needed for this endpoint.
    public func sessionLogin(_ info: API.Request.Login, type: API.Request.Session) -> SignalProducer<API.Credentials,API.Error> {
        switch type {
        case .certificate: return self.certificateLogin(info)
        case .oauth: return self.oauthLogin(info)
        }
    }
    
    /// Returns the user's session details.
    /// - returns: `SignalProducer` returning information about the current user's session.
    public func session() -> SignalProducer<API.Response.Session,API.Error> {
        return self.makeRequest(.get, "session", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: [200])
            .decodeJSON()
    }
    
    /// Log out from the current session.
    ///
    /// If the API instance didn't have any credentials (i.e. a user was not logged in), the response is successful.
    /// - returns: `SignalProducer` indicating the success of the operation.
    public func sessionLogout() -> SignalProducer<Void,API.Error> {
        return SignalProducer { [weak weakAPI = self] (generator, lifetime) in
            guard let api = weakAPI else {
                return generator.send(error: .sessionExpired)
            }
            guard let creds = try? api.credentials() else {
                generator.send(value: ())
                return generator.sendCompleted()
            }
            
            let url = api.rootURL.appendingPathComponent("session")
            let request = URLRequest(url: url).set {
                $0.setMethod(.delete)
                $0.addHeaders(version: 1, credentials: creds)
            }
            
            let disposable = SignalProducer<API.Request.Wrapper,API.Error>(value: (request,api))
                .send()
                .validate(statusCodes: [204])
                .start {
                    switch $0 {
                    case .value(_):
                        weakAPI?.removeCredentials()
                        generator.send(value: ())
                    case .completed: generator.sendCompleted()
                    case .failed(let e): generator.send(error: e)
                    case .interrupted: generator.sendInterrupted()
                    }
                }
            lifetime.observeEnded(disposable.dispose)
        }
    }
    
    /// Switches active accounts, optionally setting the default account.
    ///
    /// The identifier of the account to switch to must be different than the current account or the signal will fail.
    /// - parameter accountId: The identifier for the account that the user want to switch to.
    /// - parameter makingDefault: Boolean indicating whether the new account should be made the default one.
    /// - returns: `SignalProducer` indicating the success of the operation.
//    public func sessionSwitch(to accountId: String, makingDefault: Bool = false) -> SignalProducer<API.Response.Session.Switch,API.Error> {
//        let paco = self.makeRequest(.put, "session", version: 1, credentials: true, headers: <#T##[API.HTTP.Header.Key : String]?#>, body: {
//            return (.json, )
//        })
//
//        let credentials = try api.credentials()
//        guard credentials.accountId != accountId else {
//            throw API.Error.invalidRequest(underlyingError: nil, message: "Session switch failed! The account identifier to switch to must be different than the active account.")
//        }
//    }
}

extension API.Request {
    /// Type of sessions available
    public enum Session {
        /// Certificates sessions last a default of 6 hours, but can get extended up to a maximum of 72 hours while they are in use.
        case certificate
        /// OAuth sessions are valid for a limited period (e.g. 60 seconds) as specified in the expiration date from the response.
        case oauth
    }
}

extension API.Response {
    /// Representation of a dealing session.
    public struct Session: Decodable {
        /// Client identifier.
        public let clientId: Int
        /// Active account identifier.
        public let accountId: String
        /// Lightstreamer endpoint for subscribing to account and price updates.
        public let streamerURL: URL
        /// Timezone of the active account.
        public let timezone: TimeZone
        /// The language locale to use on the platform
        public let locale: Locale
        /// The default currency used in this session.
        public let currency: String
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let clientString = try container.decode(String.self, forKey: .clientId)
            self.clientId = try Int(clientString)
                ?! DecodingError.typeMismatch(Int.self, .init(codingPath: container.codingPath, debugDescription: "The clientId \"\(clientString)\" couldn't be parsed to a number."))
            self.accountId = try container.decode(String.self, forKey: .accountId)
            let offset = try container.decode(Int.self, forKey: .timezoneOffset)
            self.timezone = try TimeZone(secondsFromGMT: offset * 3600)
                ?! DecodingError.dataCorruptedError(forKey: .timezoneOffset, in: container, debugDescription: "The timezone couldn't be parsed into a Foundation TimeZone structure.")
//                API.Response.Session.Error.invalidTimeZone(offset: offset)
            self.streamerURL = try container.decode(URL.self, forKey: .streamerURL)
            self.locale = Locale(identifier: try container.decode(String.self, forKey: .locale))
            self.currency = try container.decode(String.self, forKey: .currency)
        }
        
        private enum CodingKeys: String, CodingKey {
            case clientId, accountId, timezoneOffset
            case locale, currency, streamerURL = "lightstreamerEndpoint"
        }
    }
}

extension API.Response.Session {
    /// Encryption key message returned from the server.
    public struct EncryptionKey: Decodable {
        /// The key (in base 64) to be used on encryption.
        public let encryptionKey: String
        /// Current timestamp in milliseconds since epoch.
        public let timeStamp: Date
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.encryptionKey = try container.decode(String.self, forKey: .encryptionKey)
            let epoch = try container.decode(Double.self, forKey: .timeStamp)
            self.timeStamp = Date(timeIntervalSince1970: epoch * 0.001)
        }
        
        private enum CodingKeys: String, CodingKey {
            case encryptionKey, timeStamp
        }
    }
}

extension API.Response.Session {
    /// Payload received when accounts are switched.
    public struct Switch: Decodable {
        ///
        public let isTrailingStopEnabled: Bool
        ///
        public let isDealingEnabled: Bool
        ///
        public let hasActiveDemoAccounts: Bool
        ///
        public let hasActiveLiveAccounts: Bool
        
        private enum CodingKeys: String, CodingKey {
            case isTrailingStopEnabled = "trailingStopsEnabled"
            case isDealingEnabled = "dealingEnabled"
            case hasActiveDemoAccounts, hasActiveLiveAccounts
        }
    }
}
