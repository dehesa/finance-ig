@testable import IG
import XCTest
import Combine
import Foundation

extension Test {
    /// Contains the loging information for the testing environment.
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
        /// Blob gathering the required token certificate data.
        typealias TokenCertificate = (access: String, security: String)
        /// Blob gathering the required OAuth token data.
        typealias TokenOAuth = (access: String, refresh: String, scope: String, type: String)
        /// The root URL from where to call the endpoints.
        ///
        /// If this references a folder in the bundles file system, it shall be of type:
        /// ```
        /// file://API
        /// ```
        let rootURL: URL
        /// The API key used to identify the developer.
        let key: IG.API.Key
        /// The actual user name and password used for this test account.
        let user: IG.API.User?
        /// The certificate token being appended to all API endpoints.
        let certificate: TokenCertificate?
        /// The OAuth token being appended to all API endpoints.
        let oauth: TokenOAuth?
        
        init(url: URL, key: IG.API.Key, user: IG.API.User? = nil, certificate: TokenCertificate? = nil, oauth: TokenOAuth? = nil) {
            self.rootURL = url
            self.key = key
            self.user = user
            self.certificate = certificate
            self.oauth = oauth
        }
        
        /// Semaphore used to modified the data.
        fileprivate let _semaphore = DispatchSemaphore(value: 1)
        /// Cached credentials
        fileprivate var _cached: API.Credentials? = nil
    }
}

// MARK: - Streamer Data

extension Test.Account {
    /// Account test environment Streamer information.
    final class StreamerData {
        /// Semaphore used to modified the data.
        private let _semaphore = DispatchSemaphore(value: 1)
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

// MARK: Testing

extension XCTestCase {
    /// Returns the API credentials for this Test account.
    func apiCredentials(from testAccount: Test.Account) -> API.Credentials {
        let data: Test.Account.APIData = testAccount.api
        
        let timeout = 3
        guard case .success = data._semaphore.wait(timeout: .now() + .seconds(timeout)) else {
            fatalError("The semaphore for accessing the API credentials timeout (\(timeout) seconds)")
        }
        defer { data._semaphore.signal() }
        
        if let credentials = data._cached {
            guard credentials.token.isExpired else { return credentials }
        }
        
        let api: API = .init(rootURL: data.rootURL, credentials: data._cached, targetQueue: nil, qos: .default)
        let result: API.Credentials
        if case .some = api.channel.credentials {
            api.session.refresh()
                .expectsCompletion(timeout: 1.5, on: self)
            result = api.channel.credentials!
        } else if let cer = data.certificate {
            let token = IG.API.Token(.certificate(access: cer.access, security: cer.security), expiresIn: 6 * 60 * 60)
            let s = api.session.get(key: data.key, token: token)
                .expectsOne(timeout: 2, on: self)
            result = .init(client: s.client, account: s.account, key: data.key, token: token, streamerURL: s.streamerURL, timezone: s.timezone)
        } else if let oau = data.oauth {
            let token: IG.API.Token = .init(.oauth(access: oau.access, refresh: oau.refresh, scope: oau.scope, type: oau.type), expiresIn: 59)
            let s = api.session.get(key: data.key, token: token)
                .expectsOne(timeout: 2, on: self)
            result = .init(client: s.client, account: s.account, key: data.key, token: token, streamerURL: s.streamerURL, timezone: s.timezone)
        } else if let user = data.user {
            api.session.login(type: .certificate, key: data.key, user: user)
                .expectsCompletion(timeout: 1.5, on: self)
            result = api.channel.credentials!
        } else {
            fatalError("Some type of information must be provided to retrieve the API credentials")
        }
        
        data._cached = result
        return result
    }
}

extension XCTestCase {
    /// Try to get the Streamer credentials from the test data, and if it is not there it lets the API compute them.
    func streamerCredentials(from testAccount: Test.Account) -> (rootURL: URL, credentials: Streamer.Credentials) {
        guard case .some(let data) = testAccount.streamer else {
            let credentials = self.apiCredentials(from: testAccount)
            return (credentials.streamerURL, try! .init(credentials: credentials))
        }
        
        if let creds = data.credentials {
            return (data.rootURL, creds)
        }
        
        return (data.rootURL, try! .init(credentials: self.apiCredentials(from: testAccount)))
    }
}
