import Combine
import Foundation

extension API.Request {
    /// Contains all functionality and variables related to the running API session.
    public struct Session {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        internal unowned let api: API
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoints.
        @usableFromInline internal init(api: API) { self.api = api }
    }
}

extension API.Request.Session {
    /// The credentials for the current session (at the time of call).
    public var credentials: API.Credentials? {
        self.api.channel.credentials
    }
    
    /// Boolean indicating whether the API can perform priviledge endpoints.
    ///
    /// To return `true`, there must be credentials in the session and the token must not be expired.
    public var isActive: Bool {
        guard let credentials = self.api.channel.credentials else { return false }
        return !credentials.token.isExpired
    }
    
    /// The credentials status for the receiving API instance.
    public var status: API.Session.Status {
        self.api.channel.status
    }
    
    /// Returns a publisher outputting session events such as `.logout`, `.ready`, or `.expired`.
    /// - remark: The subject never fails and only completes successfully when the `API` instance gets deinitialized.
    /// - returns: Publisher emitting unique status values.
    public var statusStream: AnyPublisher<API.Session.Status,Never> {
        self.api.channel.statusStream(on: self.api.queue)
            .eraseToAnyPublisher()
    }

    // MARK: POST /session

    /// Logs a user in the platform and stores the credentials within the API instance.
    ///
    /// This method will change the credentials stored within the API instance (in case of successfull endpoint call).
    /// - note: No credentials are needed for this endpoint (i.e. the `API` instance doesn't need to be previously logged in).
    /// - parameter key: API key given by the platform identifying the usage of the IG endpoints.
    /// - parameter user: User name and password to log in into an IG account.
    /// - returns: *Future* indicating a login success with a successful complete event. If the login is of `.certificate` type, extra information on the session settings is forwarded as a value. The `.oauth` login type will simply complete successfully for successful operations (without forwarding any value).
    public func login(type: Self.Kind, key: API.Key, user: API.User) -> AnyPublisher<API.Session.Settings,IG.Error> {
        switch type {
        case .certificate:
            return self.loginCertificate(key: key, user: user, encryptPassword: false)
                .tryMap { [weak weakAPI = self.api] (credentials, settings) in
                    guard let api = weakAPI else {
                        throw IG.Error(.api(.sessionExpired), "The API instance has been deallocated.", help: "The API functionality is asynchronous. Keep around the API instance while the request/response is being processed.")
                    }
                    api.channel.credentials = credentials
                    return settings
                }.mapError(errorCast)
                .eraseToAnyPublisher()
        case .oauth:
            return self.loginOAuth(key: key, user: user)
                .tryCompactMap { [weak weakAPI = self.api] (credentials) -> API.Session.Settings? in
                    guard let api = weakAPI else {
                        throw IG.Error(.api(.sessionExpired), "The API instance has been deallocated.", help: "The API functionality is asynchronous. Keep around the API instance while the request/response is being processed.")
                    }
                    api.channel.credentials = credentials
                    return nil
                }.mapError(errorCast)
                .eraseToAnyPublisher()
        }
    }

    /// Refreshes the underlying secret token so the session can remain connected for longer time.
    ///
    /// This method applies the correct refresh depending on the underlying token (whether OAuth or credentials).
    /// - note: OAuth refreshes are intended to happen often (less than 1 minute), while certificate refresh should happen infrequently (every 3 to 4 hours).
    /// - returns: *Future* indicating a successful token refresh with a successful complete.
    public func refresh() -> AnyPublisher<Never,IG.Error> {
        self.api.publisher { (api) -> API.Credentials in
                try api.channel.credentials ?> IG.Error(.api(.invalidRequest), "No credentials were found on the API instance.", help: "Log in before calling this request.")
            }.mapError { $0 as Swift.Error }
            .flatMap { (api, credentials) -> AnyPublisher<API.Token,Swift.Error> in
                switch credentials.token.value {
                case .certificate: return api.session.refreshCertificate()
                case .oauth(_, let refresh, _, _): return api.session.refreshOAuth(token: refresh, key: credentials.key)
                }
            }.tryCompactMap { [weak weakAPI = self.api] (token) in
                guard let api = weakAPI else {
                    throw IG.Error(.api(.sessionExpired), "The API instance has been deallocated.", help: "The API functionality is asynchronous. Keep around the API instance while the request/response is being processed.")
                }
                try api.channel.setCredentials { (oldCredentials) in
                    guard var newCredentials = oldCredentials else {
                        throw IG.Error(.api(.sessionExpired), "No credentials were found on the API instance.", help: "You seem to have log out during the execution of this endpoint. Please, remain logged in next time")
                    }
                    newCredentials.token = token
                    return newCredentials
                }
                return nil
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }

    // MARK: GET /session

    /// Returns the user's session details.
    /// - returns: *Future* forwarding the user's session details.
    public func get() -> AnyPublisher<API.Session,IG.Error> {
        self.api.publisher
            .makeRequest(.get, "session", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }

    /// Returns the user's session details for the given credentials.
    /// - note: No credentials needed (besides the provided ones as parameter). That is the API instance doesn't need to be logged in.
    /// - parameter key: API key given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter token: The credentials for the user session to query.
    /// - returns: *Future* forwarding information about the current user's session.
    public func get(key: API.Key, token: API.Token) -> AnyPublisher<API.Session,IG.Error> {
        self.api.publisher
            .makeRequest(.get, "session", version: 1, credentials: false, headers: {
                var result = [API.HTTP.Header.Key.apiKey: key.rawValue]
                switch token.value {
                case .certificate(let access, let security):
                    result[.clientSessionToken] = access
                    result[.securityToken] = security
                case .oauth(let access, _, _, let type):
                    result[.authorization] = "\(type) \(access)"
                }
                return result
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }

    // MARK: PUT /session

    /// Switches active accounts, optionally setting the default account.
    ///
    /// This method will change the credentials stored within the API instance (in case of successfull endpoint call).
    /// - attention: The identifier of the account to switch to must be different than the current account or the server will return an error.
    /// - parameter accountId: The identifier for the account that the user want to switch to.
    /// - parameter makingDefault: Boolean indicating whether the new account should be made the default one.
    /// - returns: *Future* indicating a successful account switch with a successful complete.
    public func `switch`(to accountId: IG.Account.Identifier, makingDefault: Bool = false) -> AnyPublisher<API.Session.Settings,IG.Error> {
        self.api.publisher
            .makeRequest(.put, "session", version: 1, credentials: true, body: {
                let payload = _PayloadSwitch(accountId: accountId.rawValue, defaultAccount: makingDefault)
                return (.json, try JSONEncoder().encode(payload))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { [weak weakAPI = self.api] (sessionSwitch: API.Session.Settings, call) throws in
                guard let api = weakAPI else {
                    throw IG.Error(.api(.sessionExpired), "The API instance has been deallocated.", help: "The API functionality is asynchronous. Keep around the API instance while the request/response is being processed.")
                }
                try api.channel.setCredentials { (oldCredentials) in
                    guard var newCredentials = oldCredentials else {
                        throw IG.Error(.api(.invalidResponse), "No credentials were found on the API instance.", help: "API functionality is asynchronous; keep around the API instance while a response hasn't been received", info: ["Request": call.request, "Response": call.response])
                    }
                    newCredentials.account = accountId
                    return newCredentials
                }
                return sessionSwitch
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }

    // MARK: DELETE /session

    /// Log out from the current session.
    ///
    /// This method will delete the credentials stored in the API instance (in case of successful endpoint call).
    /// - note: If the API instance didn't have any credentials (i.e. a user was not logged in), the response is successful.
    /// - returns: *Future* indicating a succesful logout operation with a sucessful complete.
    public func logout() -> AnyPublisher<Never,IG.Error> {
        self.api.publisher
            .makeRequest(.delete, "session", version: 1, credentials: true)
            .send(statusCode: 204)
            .compactMap { [weak weakAPI = self.api] _ in weakAPI?.channel.credentials = nil; return nil }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension API.Request.Session {
    /// Type of sessions available
    public enum Kind {
        /// Certificates sessions last a default of 6 hours, but can get extended up to a maximum of 72 hours while they are in use.
        case certificate
        /// OAuth sessions are valid for a limited period (e.g. 60 seconds) as specified in the expiration date from the response.
        case oauth
    }
    
    /// Payload for the session switch request.
    private struct _PayloadSwitch: Encodable {
        let accountId: String
        let defaultAccount: Bool
    }
}

extension API {
    /// Representation of a dealing session.
    public struct Session: Decodable {
        /// Client identifier.
        public let client: IG.Client.Identifier
        /// Active account identifier.
        public let account: IG.Account.Identifier
        /// Lightstreamer endpoint for subscribing to account and price updates.
        public let streamerURL: URL
        /// Timezone of the active account.
        public let timezone: TimeZone
        /// The language locale to use on the platform
        public let locale: Locale
        /// The default currency used in this session.
        public let currencyCode: Currency.Code
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: _CodingKeys.self)
            self.client = try container.decode(IG.Client.Identifier.self, forKey: .client)
            self.account = try container.decode(IG.Account.Identifier.self, forKey: .account)
            let offset = try container.decode(Int.self, forKey: .timezoneOffset)
            self.timezone = try TimeZone(secondsFromGMT: offset * 3600)
                ?> DecodingError.dataCorruptedError(forKey: .timezoneOffset, in: container, debugDescription: "The timezone couldn't be parsed into a Foundation TimeZone structure")
            self.streamerURL = try container.decode(URL.self, forKey: .streamerURL)
            self.locale = Locale(identifier: try container.decode(String.self, forKey: .locale))
            self.currencyCode = try container.decode(Currency.Code.self, forKey: .currencyCode)
        }
        
        private enum _CodingKeys: String, CodingKey {
            case client = "clientId"
            case account = "accountId"
            case timezoneOffset, locale
            case currencyCode = "currency"
            case streamerURL = "lightstreamerEndpoint"
        }
    }
}

extension API.Session {
    /// The session status.
    public enum Status: Equatable {
        /// There are no credentials within the current session.
        case logout
        /// There are credentials and they haven't yet expired.
        case ready(till: Date)
        /// There are credentials, but they have already expired.
        case expired
    }
    
    /// Payload received when accounts are switched.
    public struct Settings: Decodable {
        /// Boolean indicating whether trailing stops are currently enabled for the given account.
        public let isTrailingStopEnabled: Bool
        /// Boolean indicating whether it is possible to make "deals" on the given account.
        public let isDealingEnabled: Bool
        /// Boolean indicating whther the demo account is active.
        public let hasActiveDemoAccounts: Bool
        /// Boolean indicating whether the live account is active.
        public let hasActiveLiveAccounts: Bool
        
        private enum CodingKeys: String, CodingKey {
            case isTrailingStopEnabled = "trailingStopsEnabled"
            case isDealingEnabled = "dealingEnabled"
            case hasActiveDemoAccounts, hasActiveLiveAccounts
        }
    }
}
