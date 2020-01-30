import XCTest
import Combine
import Foundation

/// Holder for the test data and credentials information.
enum Test {
    /// Restrict access to the `cache` storage.
    private static let semaphore = DispatchSemaphore(value: 1)
    /// Stores test accounts for running tests.
    private static var cache: [String:Test.Account] = [:]
    
    /// The default environment key being used to identify where the test account data is.
    static let defaultEnvironmentKey: String = "io.dehesa.ig.tests.account"
    
    /// Returns a shared test account.
    ///
    /// Sharing is done so all test accounts don't have to log in. If you want a non shareable one, use the `Test.Account` initializer isntead.
    /// ```
    /// let shared = Test.account(environmentKey: "...")
    /// let unique = Test.Account(environmentKey: "...")
    /// ```
    static func account(environmentKey: String, timeout: DispatchTimeInterval = .seconds(2)) -> Test.Account {
        guard case .success = self.semaphore.wait(timeout: .now() + timeout) else {
            fatalError("The semaphore for accessing the Test accounts timeout (\(timeout) seconds)")
        }
        
        if let result = self.cache[environmentKey] {
            self.semaphore.signal()
            return result
        } else {
            let result = Test.Account(environmentKey: environmentKey)
            self.cache[environmentKey] = result
            self.semaphore.signal()
            return result
        }
    }
}
