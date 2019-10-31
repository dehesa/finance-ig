@testable import IG
import XCTest

/// Tests API transaction retrieval
final class APITransactionTests: XCTestCase {
    /// Tests paginated transaction retrieval.
    func testTransactions() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
        let transactions = api.history.getTransactionsContinuously(from: Date().lastTuesday)
            .expectsAll(timeout: 2, on: self)
            .flatMap { $0 }
        XCTAssertFalse(transactions.isEmpty)
        
        for transaction in transactions {
            XCTAssertFalse(transaction.title.isEmpty)
            XCTAssertFalse(transaction.reference.isEmpty)
            XCTAssertFalse(transaction.debugDescription.isEmpty)
        }
    }
}
