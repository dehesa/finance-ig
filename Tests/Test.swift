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
            
            let key = Test.account.api.key
            let result: Result<API.Credentials, API.Error>
            
            switch Test.account.api.credentials {
            case .user(let user):
                result = api.session.loginCertificate(key: key, user: user).single()!.map { (creds, settings) in creds }
            case .certificate(let access, let security):
                let token = API.Credentials.Token(.certificate(access: access, security: security), expiresIn: 6 * 60 * 60)
                result = api.session.get(key: key, token: token).map {
                    API.Credentials(client: $0.client, account: $0.account, key: key, token: token, streamerURL: $0.streamerURL, timezone: $0.timezone)
                }.single()!
            case .oauth(let access, let refresh, let scope, let type):
                let token = API.Credentials.Token(.oauth(access: access, refresh: refresh, scope: scope, type: type), expiresIn: 59)
                result = api.session.get(key: key, token: token).map {
                    API.Credentials(client: $0.client, account: $0.account, key: key, token: token, streamerURL: $0.streamerURL, timezone: $0.timezone)
                }.single()!
            }

            switch result {
            case .success(let creds): self.apiCredentials = creds; return creds
            case .failure(let error): fatalError("\(error)")
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
                self.streamerCredentials = try! .init(credentials: apiCredentials)
                return self.streamerCredentials!
            }
            
            var api: IG.API! = .init(rootURL: Test.account.api.rootURL, credentials: apiCredentials)
            defer { api = nil }
            
            switch api.session.refreshCertificate().single() {
            case .none: fatalError("The certificate credentials couldn't be fetched from the server on the root URL: \(api.rootURL)")
            case .failure(let error): fatalError("\(error)")
            case .success(let token):
                apiCredentials.token = token
                self.streamerCredentials = try! .init(credentials: apiCredentials)
                return self.streamerCredentials!
            }
        }
    }
}
