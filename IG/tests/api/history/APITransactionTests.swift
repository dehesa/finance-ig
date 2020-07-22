@testable import IG
import ConbiniForTesting
import XCTest

/// Tests API transaction retrieval
final class APITransactionTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let _acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Tests paginated transaction retrieval.
    func testTransactions() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: self.apiCredentials(from: self._acc), targetQueue: nil)
        
        let transactions = api.accounts.getTransactionsContinuously(from: Date().lastTuesday)
            .expectsAll(timeout: 2, on: self)
            .flatMap { $0 }
        XCTAssertFalse(transactions.isEmpty)
        
        for transaction in transactions {
            XCTAssertFalse(transaction.title.isEmpty)
            XCTAssertFalse(transaction.reference.isEmpty)
//            XCTAssertFalse(transaction.debugDescription.isEmpty)
        }
    }
}
