import Combine
import Foundation

extension IG.API.Request {
    /// Contains all functionality and variables related to the running API session.
    public struct Session {
        /// Pointer to the API instance in charge of calling the session endpoints.
        private var pointer: Unmanaged<IG.API>?
        /// The credentials used to call API endpoints.
        internal var credentials: IG.API.Credentials?
        
        /// Pointer to the actual API instance in charge of calling the endpoint.
        /// - important: Before using the getter, be sure to have set this property or the application will crash.
        internal var api: IG.API {
            get { return pointer!.takeUnretainedValue() }
            set { self.pointer = Unmanaged<IG.API>.passUnretained(newValue) }
        }
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the session endpoints.
        /// - parameter credentials: The credentials to be stored within this API session.
        internal init(credentials: IG.API.Credentials?) {
            self.pointer = nil
            self.credentials = credentials
        }
        
        /// Returns the API application key of the session being used (or logged in).
        public var key: IG.API.Key? {
            return self.credentials?.key
        }
        /// Returns the client identifier of the session being used (or logged in).
        public var client: IG.Client.Identifier? {
            return self.credentials?.client
        }
        /// Returns the account identifier of the session being used (or logged in).
        public var account: IG.Account.Identifier? {
            return self.credentials?.account
        }
    }
}

extension IG.API.Request.Session {

    // MARK: POST /session

    /// Logs a user in the platform and stores the credentials within the API instance.
    ///
    /// This method will change the credentials stored within the API instance (in case of successfull endpoint call).
    /// - note: No credentials are needed for this endpoint (i.e. the `API` instance doesn't need to be previously logged in).
    /// - parameter key: API key given by the platform identifying the usage of the IG endpoints.
    /// - parameter user: User name and password to log in into an IG account.
    /// - returns: *Future* indicating a login success with a successful complete event. If the login is of `.certificate` type, extra information on the session settings is forwarded as a value. The `.oauth` login type will simply complete successfully for successful operations (without forwarding any value).
    public func login(type: Self.Kind, key: IG.API.Key, user: IG.API.User) -> IG.API.DiscretePublisher<IG.API.Session.Settings> {
        switch type {
        case .certificate:
            return self.loginCertificate(key: key, user: user, encryptPassword: false)
                .tryMap { [weak weakAPI = self.api] (credentials, settings) in
                    guard let api = weakAPI else { throw IG.API.Error.sessionExpired() }
                    api.session.credentials = credentials
                    return settings
                }.mapError(IG.API.Error.transform)
                .eraseToAnyPublisher()
        case .oauth:
            return self.loginOAuth(key: key, user: user)
                .tryMap { [weak weakAPI = self.api] (credentials) in
                    guard let api = weakAPI else { throw IG.API.Error.sessionExpired() }
                    api.session.credentials = credentials
                }.flatMap(maxPublishers: .max(1), { (_) in
                    Empty(completeImmediately: true)
                }).mapError(IG.API.Error.transform)
                .eraseToAnyPublisher()
        }
    }

    /// Refreshes the underlying secret token so the session can remain connected for longer time.
    ///
    /// This method applies the correct refresh depending on the underlying token (whether OAuth or credentials).
    /// - note: OAuth refreshes are intended to happen often (less than 1 minute), while certificate refresh should happen infrequently (every 3 to 4 hours).
    /// - returns: *Future* indicating a successful token refresh with a successful complete.
    public func refresh() -> IG.API.DiscretePublisher<Never> {
        self.api.publisher { (api) -> IG.API.Credentials in
                try api.session.credentials ?! IG.API.Error.invalidRequest(.noCredentials, suggestion: .logIn)
            }.mapError{
                $0 as Swift.Error
            }.flatMap(maxPublishers: .max(1)) { (api, credentials) -> AnyPublisher<IG.API.Credentials.Token,Swift.Error> in
                switch credentials.token.value {
                case .certificate: return api.session.refreshCertificate()
                case .oauth(_, let refresh, _, _): return api.session.refreshOAuth(token: refresh, key: credentials.key)
                }
            }.tryMap { [weak weakAPI = self.api] (token) -> Void in
                guard let api = weakAPI else { throw IG.API.Error.sessionExpired() }
                guard var credentials = api.session.credentials else {
                    let suggestion = "You seem to have log out during the execution of this endpoint. Please, remain logged in next time"
                    throw IG.API.Error.sessionExpired(message: .noCredentials, suggestion: .init(suggestion))
                }
                credentials.token = token
                api.session.credentials = credentials
            }.ignoreOutput()
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }

    // MARK: GET /session

    /// Returns the user's session details.
    /// - returns: *Future* forwarding the user's session details.
    public func get() -> IG.API.DiscretePublisher<IG.API.Session> {
        self.api.publisher
            .makeRequest(.get, "session", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }

    /// Returns the user's session details for the given credentials.
    /// - note: No credentials needed (besides the provided ones as parameter). That is the API instance doesn't need to be logged in.
    /// - parameter key: API key given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter token: The credentials for the user session to query.
    /// - returns: *Future* forwarding information about the current user's session.
    public func get(key: IG.API.Key, token: IG.API.Credentials.Token) -> IG.API.DiscretePublisher<IG.API.Session> {
        self.api.publisher
            .makeRequest(.get, "session", version: 1, credentials: false, headers: {
                var result = [IG.API.HTTP.Header.Key.apiKey: key.rawValue]
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
            .mapError(IG.API.Error.transform)
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
    public func `switch`(to accountId: IG.Account.Identifier, makingDefault: Bool = false) -> IG.API.DiscretePublisher<IG.API.Session.Settings> {
        self.api.publisher
            .makeRequest(.put, "session", version: 1, credentials: true, body: {
                let payload = Self.PayloadSwitch(accountId: accountId.rawValue, defaultAccount: makingDefault)
                return (.json, try JSONEncoder().encode(payload))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { [weak weakAPI = self.api] (sessionSwitch: IG.API.Session.Settings, call) throws in
                guard let api = weakAPI else { throw IG.API.Error.sessionExpired() }
                guard var credentials = api.session.credentials else { throw IG.API.Error.invalidResponse(message: .noCredentials, request: call.request, response: call.response, suggestion: .keepSession) }
                
                credentials.account = accountId
                api.session.credentials = credentials
                return sessionSwitch
            }.mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }

    // MARK: DELETE /session

    /// Log out from the current session.
    ///
    /// This method will delete the credentials stored in the API instance (in case of successful endpoint call).
    /// - note: If the API instance didn't have any credentials (i.e. a user was not logged in), the response is successful.
    /// - returns: *Future* indicating a succesful logout operation with a sucessful complete.
    public func logout() -> IG.API.DiscretePublisher<Never> {
        self.api.publisher
            .makeRequest(.delete, "session", version: 1, credentials: true)
            .send(statusCode: 204)
            .map { [weak weakAPI = self.api] (_) in weakAPI?.session.credentials = nil }
            .ignoreOutput()
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension IG.API.Request.Session {
    /// Type of sessions available
    public enum Kind {
        /// Certificates sessions last a default of 6 hours, but can get extended up to a maximum of 72 hours while they are in use.
        case certificate
        /// OAuth sessions are valid for a limited period (e.g. 60 seconds) as specified in the expiration date from the response.
        case oauth
    }
    
    /// Payload for the session switch request.
    private struct PayloadSwitch: Encodable {
        let accountId: String
        let defaultAccount: Bool
    }
}

extension IG.API {
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
        public let currencyCode: IG.Currency.Code
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.client = try container.decode(IG.Client.Identifier.self, forKey: .client)
            self.account = try container.decode(IG.Account.Identifier.self, forKey: .account)
            let offset = try container.decode(Int.self, forKey: .timezoneOffset)
            self.timezone = try TimeZone(secondsFromGMT: offset * 3600)
                ?! DecodingError.dataCorruptedError(forKey: .timezoneOffset, in: container, debugDescription: "The timezone couldn't be parsed into a Foundation TimeZone structure")
            self.streamerURL = try container.decode(URL.self, forKey: .streamerURL)
            self.locale = Locale(identifier: try container.decode(String.self, forKey: .locale))
            self.currencyCode = try container.decode(IG.Currency.Code.self, forKey: .currencyCode)
        }
        
        private enum CodingKeys: String, CodingKey {
            case client = "clientId"
            case account = "accountId"
            case timezoneOffset, locale
            case currencyCode = "currency"
            case streamerURL = "lightstreamerEndpoint"
        }
    }
}

extension IG.API.Session {
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

// MARK: - Functionality

extension IG.API.Session: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.API.printableDomain).\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("client ID", self.client)
        result.append("account ID", self.account)
        result.append("streamer URL", self.streamerURL.absoluteString)
        result.append("timezone", self.timezone.description)
        result.append("locale", self.locale.description)
        result.append("currency code", self.currencyCode)
        return result.generate()
    }
}

extension IG.API.Session.Settings: IG.DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.API.Session.printableDomain).\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("trailing stops", self.isTrailingStopEnabled)
        result.append("dealing", self.isDealingEnabled)
        result.append("active demo account", self.hasActiveDemoAccounts)
        result.append("active live account", self.hasActiveLiveAccounts)
        return result.generate()
    }
}
