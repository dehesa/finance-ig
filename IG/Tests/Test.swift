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
