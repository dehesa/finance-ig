import ReactiveSwift
import Foundation

extension API.Request.Session {
    
    // MARK: POST /session
    
    /// Logs a user in the platform and stores the credentials within the API instance.
    ///
    /// This method will change the credentials stored within the API instance (in case of successfull endpoint call).
    /// - note: No credentials are needed for this endpoint.
    /// - parameter apiKey: API key given by the IG platform identifying the usage of the IG endpoints.
    /// - parameter user: User name and password to log in into an IG account.
    /// - returns: `SignalProducer` indicating whether the endpoint was successful.
    public func login(type: Self.Kind, apiKey: String, user: (name: String, password: String)) -> SignalProducer<Void,API.Error> {
        var result: SignalProducer<API.Credentials,API.Error>
        
        switch type {
        case .certificate:
            result = self.loginCertificate(apiKey: apiKey, user: user, encryptPassword: false)
        case .oauth:
            result = self.loginOAuth(apiKey: apiKey, user: user)
        }
        
        return result.map { [weak weakAPI = self.api] (credentials) in
            weakAPI?.session.credentials = credentials
            return ()
        }
    }

    // MARK: GET /session

    /// Returns the user's session details.
    /// - returns: `SignalProducer` returning information about the current user's session.
    public func get() -> SignalProducer<API.Session,API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "session", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
    }
    
    /// Returns the user's session details for the given credentials.
    /// - note: No credentials (besides the provided ones as parameter) are needed for this endpoint.
    /// - parameter token: The credentials for the user session to query.
    /// - returns: `SignalProducer` returning information about the current user's session.
    public func get(apiKey: String, token: API.Credentials.Token) -> SignalProducer<API.Session,API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "session", version: 1, credentials: false, headers: { (_,_) in
                var result = [API.HTTP.Header.Key.apiKey: apiKey]
                switch token.value {
                case .certificate(let access, let security):
                    result[.clientSessionToken] = access
                    result[.securityToken] = security
                case .oauth(let access, _, _, let type):
                    result[.authorization] = "\(type) \(access)"
                }
                return result
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
    }

    // MARK: PUT /session
    
    /// Switches active accounts, optionally setting the default account.
    ///
    /// This method will change the credentials stored within the API instance (in case of successfull endpoint call).
    /// - attention: The identifier of the account to switch to must be different than the current account or the server will return an error.
    /// - parameter accountId: The identifier for the account that the user want to switch to.
    /// - parameter makingDefault: Boolean indicating whether the new account should be made the default one.
    /// - returns: `SignalProducer` indicating the success of the operation.
    public func `switch`(to accountId: String, makingDefault: Bool = false) -> SignalProducer<API.Session.Switch,API.Error> {
        return SignalProducer(api: self.api) { (api) -> Self.PayloadSwitch in
                guard !accountId.isEmpty else {
                    throw API.Error.invalidRequest(underlyingError: nil, message: "The account identifier cannot be empty.")
                }
                return .init(accountId: accountId, defaultAccount: makingDefault)
            }.request(.put, "session", version: 1, credentials: true, body: { (_, payload) in
                let data = try JSONEncoder().encode(payload)
                return (.json, data)
            }).send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .attemptMap { [weak weakAPI = self.api] (sessionSwitch: API.Session.Switch) -> Result<API.Session.Switch,API.Error> in
                guard let api = weakAPI else {
                    return .failure(.sessionExpired)
                }
                
                guard var credentials = api.session.credentials else {
                    return .failure(.invalidCredentials(nil, message: "The API instance doesn't have any credentials."))
                }
                
                credentials.accountId = accountId
                api.session.credentials = credentials
                return .success(sessionSwitch)
            }
    }

    // MARK: DELETE /session
    
    /// Log out from the current session.
    ///
    /// This method will delete the credentials stored in the API instance (in case of successful endpoint call).
    /// - note: If the API instance didn't have any credentials (i.e. a user was not logged in), the response is successful.
    /// - returns: `SignalProducer` indicating the success of the operation.
    public func logout() -> SignalProducer<Void,API.Error> {
        return SignalProducer { [weak weakAPI = self.api] (input, lifetime) in
            guard let api = weakAPI else {
                return input.send(error: .sessionExpired)
            }
            
            guard let creds = api.session.credentials else {
                input.send(value: ())
                return input.sendCompleted()
            }
            
            let url = api.rootURL.appendingPathComponent("session")
            let request = URLRequest(url: url).set {
                $0.httpMethod = API.HTTP.Method.delete.rawValue
                $0.addHeaders(version: 1, credentials: creds)
            }
            
            let disposable = SignalProducer<API.Request.Wrapper,API.Error>(value: (api,request))
                .send()
                .validate(statusCodes: 204)
                .start {
                    switch $0 {
                    case .value(_):
                        weakAPI?.session.credentials = nil
                        input.send(value: ())
                    case .completed: input.sendCompleted()
                    case .failed(let e): input.send(error: e)
                    case .interrupted: input.sendInterrupted()
                    }
                }
            lifetime.observeEnded(disposable.dispose)
        }
    }
}

// MARK: - Supporting Entities

extension API.Request {
    /// Contains all functionality related to the API session.
    public struct Session {
        /// Pointer to the API instance in charge of calling the session endpoints.
        private var pointer: Unmanaged<API>?
        /// The credentials used to call API endpoints.
        var credentials: API.Credentials?
        
        /// Pointer to the actual API instance in charge of calling the endpoint.
        /// - attention: Before using the getter, be sure to have set this property or the application will crash.
        var api: API {
            get { return pointer!.takeUnretainedValue() }
            set { self.pointer = Unmanaged<API>.passUnretained(newValue) }
        }
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the session endpoints.
        /// - parameter credentials: The credentials to be stored within this API session.
        init(credentials: API.Credentials?) {
            self.pointer = nil
            self.credentials = credentials
        }
    }
}

// MARK: Request Entities

extension API.Request.Session {
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

// MARK: Response Entities

extension API {
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
        public let currency: Currency
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            let clientString = try container.decode(String.self, forKey: .clientId)
            self.clientId = try Int(clientString)
                ?! DecodingError.typeMismatch(Int.self, .init(codingPath: container.codingPath, debugDescription: "The clientId \"\(clientString)\" couldn't be parsed to a number."))
            self.accountId = try container.decode(String.self, forKey: .accountId)
            let offset = try container.decode(Int.self, forKey: .timezoneOffset)
            self.timezone = try TimeZone(secondsFromGMT: offset * 3600)
                ?! DecodingError.dataCorruptedError(forKey: .timezoneOffset, in: container, debugDescription: "The timezone couldn't be parsed into a Foundation TimeZone structure.")
            self.streamerURL = try container.decode(URL.self, forKey: .streamerURL)
            self.locale = Locale(identifier: try container.decode(String.self, forKey: .locale))
            self.currency = try container.decode(Currency.self, forKey: .currency)
        }
        
        private enum CodingKeys: String, CodingKey {
            case clientId, accountId, timezoneOffset
            case locale, currency, streamerURL = "lightstreamerEndpoint"
        }
    }
}

extension API.Session {
    /// Payload received when accounts are switched.
    public struct Switch: Decodable {
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
