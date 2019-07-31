@testable import IG
import ReactiveSwift
import Foundation

enum Test {
    /// A test account that can be share through all tests.
    static let account = Self.Account.make(from: "io.dehesa.money.ig.tests.account")
    /// Access the credentials used during the test harness.
    static let credentials: Self.Credentials = .init(timeout: .seconds(2))
}

extension Test {
    /// Holder (and fetcher) for the API and Streamer credentials.
    class Credentials {
        /// The default timeout waiting for the semaphore to succeed.
        private let timeout: DispatchTimeInterval
        /// Semaphore controling the access to API credentials..
        private let apiSemaphore = DispatchSemaphore(value: 1)
        /// Hidden API credentials.
        private var apiCredentials: IG.API.Credentials? = nil
        /// Semaphore controling the access to Streamer credentials..
        private let streamerSemaphore = DispatchSemaphore(value: 1)
        /// Hidden Streamer credentials.
        private var streamerCredentials: IG.Streamer.Credentials? = nil
        
        /// Initializes the credential fetcher with a given timeout, so test are not waiting forever.
        fileprivate init(timeout: DispatchTimeInterval) {
            self.timeout = timeout
        }
        
        /// Returns the API credentials to use during the test harness.
        var api: IG.API.Credentials {
            guard case .success = self.apiSemaphore.wait(timeout: .now() + self.timeout) else { fatalError() }
            defer { self.apiSemaphore.signal() }
            
            if let credentials = self.apiCredentials { return credentials }
            
            var api: IG.API! = Test.makeAPI(credentials: nil)
            defer { api = nil }
            
            let testApiKey = Test.account.api.key
            let testCredentials = Test.account.api.credentials
            let result: Result<API.Credentials, API.Error>?
            if case .user(let user) = testCredentials {
                result = api.session.loginCertificate(apiKey: testApiKey, user: user).single()
            } else {
                let token: API.Credentials.Token
                if case .certificate(let access, let security) = testCredentials {
                    token = .init(.certificate(access: access, security: security), expiresIn: 6 * 60 * 60)
                } else if case .oauth(let access, let refresh, let scope, let type) = testCredentials {
                    token = .init(.oauth(access: access, refresh: refresh, scope: scope, type: type), expiresIn: 59)
                } else { fatalError() }
                
                result = api.session.get(apiKey: testApiKey, token: token).map({ (s) -> API.Credentials in
                    .init(clientId: s.clientId, accountId: s.accountId, apiKey: testApiKey, token: token, streamerURL: s.streamerURL, timezone: s.timezone)
                }).single()
            }

            switch result {
            case .none: fatalError("The credentials couldn't be fetched from the server on root URL: \(api.rootURL)")
            case .failure(let error): fatalError("\(error)")
            case .success(let creds):
                self.apiCredentials = creds
                return creds
            }
        }
        
        /// Returns the Streamer credentials to use during the test harness.
        var streamer: IG.Streamer.Credentials {
            guard case .success = self.streamerSemaphore.wait(timeout: .now() + self.timeout) else { fatalError() }
            defer { self.streamerSemaphore.signal() }
            
            if let credentials = self.streamerCredentials { return credentials }
            
            if let user = Test.account.streamer?.credentials {
                self.streamerCredentials = .init(identifier: user.identifier, password: user.password)
                return self.streamerCredentials!
            }
            
            var apiCredentials = self.api
            if case .certificate = apiCredentials.token.value {
                self.streamerCredentials = try! apiCredentials.streamerCredentials()
                return self.streamerCredentials!
            }
            
            var api: IG.API! = .init(rootURL: Test.account.api.rootURL, credentials: apiCredentials)
            defer { api = nil }
            
            switch api.session.refreshCertificate().single() {
            case .none: fatalError("The certificate credentials couldn't be fetched from the server on the root URL: \(api.rootURL)")
            case .failure(let error): fatalError("\(error)")
            case .success(let token):
                apiCredentials.token = token
                self.streamerCredentials = try! apiCredentials.streamerCredentials()
                return self.streamerCredentials!
            }
        }
    }
}
