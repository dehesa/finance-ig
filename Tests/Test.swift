import XCTest
import Combine
import Foundation

/// Holder for the test data and credentials information.
enum Test {
    /// Restrict access to the `cache` storage.
    private static let semaphore = DispatchSemaphore(value: 1)
    /// Stores test accounts for running tests.
    private static var cache: [String:Test.Account] = [:]
    
    /// Returns a shared test account.
    ///
    /// Sharing is done so all test accounts don't have to log in. If you want a non shareable one, use the `Test.Account` initializer isntead.
    /// ```
    /// let shared = Test.account(environmentKey: "...")
    /// let unique = Test.Account(environmentKey: "...")
    /// ```
    static func account(environmentKey: String, timeout: DispatchTimeInterval = .seconds(2)) -> Test.Account {
        guard case .success = semaphore.wait(timeout: .now() + timeout) else {
            fatalError("The semaphore for accessing the Test accounts timeout (\(timeout) seconds)")
        }
        defer { semaphore.signal() }
        
        
        if let result = cache[environmentKey] { return result }
        
        let result = Test.Account.init(environmentKey: environmentKey)
        self.cache[environmentKey] = result
        return result
    }
}

//        #warning("Test: Uncomment")
//        /// Returns the Streamer credentials to use during the test harness.
//        var streamer: IG.Streamer.Credentials {
//            guard case .success = self.streamerSemaphore.wait(timeout: .now() + self.timeout) else { fatalError() }
//            defer { self.streamerSemaphore.signal() }
//
//            if let credentials = self.streamerCredentials { return credentials }
//
//            if let user = Test.account.streamer?.credentials {
//                self.streamerCredentials = .init(identifier: user.identifier, password: user.password)
//                return self.streamerCredentials!
//            }
//
//            var apiCredentials = self.api
//            if case .certificate = apiCredentials.token.value {
//                self.streamerCredentials = try! .init(credentials: apiCredentials)
//                return self.streamerCredentials!
//            }
//
//            var api: IG.API! = .init(rootURL: Test.account.api.rootURL, credentials: apiCredentials, targetQueue: nil)
//            defer { api = nil }
//
//            switch api.session.refreshCertificate().single() {
//            case .none: fatalError("The certificate credentials couldn't be fetched from the server on the root URL: \(api.rootURL)")
//            case .failure(let error): fatalError("\(error)")
//            case .success(let token):
//                apiCredentials.token = token
//                self.streamerCredentials = try! .init(credentials: apiCredentials)
//                return self.streamerCredentials!
//            }
//        }
//    }
