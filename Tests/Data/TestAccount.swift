@testable import IG
import Combine
import Foundation

extension Test {
    /// Structure containing the loging information for the testing environment.
    final class Account {
        /// The target account identifier.
        let identifier: IG.Account.Identifier
        /// List of variables required to connect to the API.
        var api: APIData
        /// List of variables required to connect to the Streamer.
        var streamer: StreamerData?
        /// List of variables required to open the underlying database file.
        var database: DatabaseData?
        
        /// Designated initializer letting you pass the test account data you want.
        init(identifier: IG.Account.Identifier, api: APIData, streamer: StreamerData? = nil, database: DatabaseData? = nil) {
            self.identifier = identifier
            self.api = api
            self.streamer = streamer
            self.database = database
        }
    }
}

// MARK: - API Data

extension Test.Account {
    /// Account test environment API information.
    final class APIData {
        typealias TokenCertificate = (access: String, security: String)
        typealias TokenOAuth = (access: String, refresh: String, scope: String, type: String)
        /// The root URL from where to call the endpoints.
        ///
        /// If this references a folder in the bundles file system, it shall be of type:
        /// ```
        /// file://API
        /// ```
        let rootURL: URL
        /// The API API key used to identify the developer.
        let key: API.Key
        /// The actual user name and password used for this test account.
        let user: API.User?
        /// The certificate token being appended to all API endpoints.
        let certificate: TokenCertificate?
        /// The OAuth token being appended to all API endpoints.
        let oauth: TokenOAuth?
        
        init(url: URL, key: API.Key, user: API.User? = nil, certificate: TokenCertificate? = nil, oauth: TokenOAuth? = nil) {
            self.rootURL = url
            self.key = key
            self.user = user
            self.certificate = certificate
            self.oauth = oauth
        }
        
        /// Semaphore used to modified the data.
        private let semaphore = DispatchSemaphore(value: 1)
        /// Cached credentials
        private var cached: API.Credentials? = nil
        /// Returns the API credentials for this Test account.
        var credentials: API.Credentials {
            let timeout = 3
            guard case .success = self.semaphore.wait(timeout: .now() + .seconds(timeout)) else {
                fatalError("The semaphore for accessing the API credentials timeout (\(timeout) seconds)")
            }
            defer { self.semaphore.signal() }
            
            if let credentials = self.cached {
                guard credentials.token.isExpired else { return credentials }
            }
            
            let api: API = .init(rootURL: self.rootURL, credentials: self.cached, targetQueue: nil)
            let result: API.Credentials
            if case .some = api.session.credentials {
                api.session.refresh().wait()
                result = api.session.credentials!
            } else if let cer = self.certificate {
                let token = API.Credentials.Token(.certificate(access: cer.access, security: cer.security), expiresIn: 6 * 60 * 60)
                let s = api.session.get(key: self.key, token: token).waitForOne()
                result = .init(client: s.client, account: s.account, key: self.key, token: token, streamerURL: s.streamerURL, timezone: s.timezone)
            } else if let oau = self.oauth {
                let token: API.Credentials.Token = .init(.oauth(access: oau.access, refresh: oau.refresh, scope: oau.scope, type: oau.type), expiresIn: 59)
                let s = api.session.get(key: self.key, token: token).waitForOne()
                result = .init(client: s.client, account: s.account, key: self.key, token: token, streamerURL: s.streamerURL, timezone: s.timezone)
            } else if let user = self.user {
                api.session.login(type: .certificate, key: self.key, user: user).wait()
                result = api.session.credentials!
            } else {
                fatalError("Some type of information must be provided to retrieve the API credentials")
            }
            
            self.cached = result
            return result
        }
    }
}

// MARK: - Streamer Data

extension Test.Account {
    /// Account test environment Streamer information.
    final class StreamerData {
        /// Semaphore used to modified the data.
        private let semaphore = DispatchSemaphore(value: 1)
        /// The root URL from where to get the streaming messages.
        ///
        /// It can be one of the followings:
        /// - a forlder in the test bundle file system (e.g. `file://Streamer`).
        /// - a https URL (e.g. `https://demo-apd.marketdatasystems.com`).
        let rootURL: URL
        /// The Lightstreamer identifier
        var identifier: IG.Account.Identifier?
        /// The Lightstreamer password
        var password: String?
        
        init(url: URL, identifier: IG.Account.Identifier? = nil, password: String? = nil) {
            self.rootURL = url
            self.identifier = nil
            self.password = nil
        }
        
        /// Returns the Streamer credentials for this Test account.
        var credentials: Streamer.Credentials? {
            guard let identifier = self.identifier, let password = self.password else { return nil }
            return .init(identifier: identifier, password: password)
        }
    }
    
    /// Try to get the Streamer credentials from the test data, and if it is not there it lets the API compute them.
    var streamerCredentials: (rootURL: URL, credentials: Streamer.Credentials) {
        guard case .some(let data) = self.streamer else {
            let credentials = self.api.credentials
            return (credentials.streamerURL, try! .init(credentials: credentials))
        }
        
        return (data.rootURL, data.credentials ?? (try! Streamer.Credentials(credentials: self.api.credentials)))
    }
}

// MARK: - Database Data

extension Test.Account {
    /// Account test environment Database information.
    final class DatabaseData {
        /// The file URL where the database file is located.
        ///
        /// If `nil` an "in memory" database will be opened.
        let rootURL: URL?
        
        init(url: URL?) {
            self.rootURL = url
        }
    }
}

// MARK: - Functionality

extension Test.Account {
    /// Supported URL schemes for the rootURL
    enum SupportedScheme: String {
        case file
        case https
        
        init?(url: URL) {
            guard let urlScheme = url.scheme,
                  let result = Self.init(rawValue: urlScheme) else { return nil }
            self = result
        }
    }
}
