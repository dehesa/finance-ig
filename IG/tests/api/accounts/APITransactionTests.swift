@testable import IG
import ConbiniForTesting
import XCTest

/// Tests API transaction retrieval
final class APITransactionTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests paginated transaction retrieval.
    func testTransactions() {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let date = Date().lastTuesday
        let transactions = api.accounts.getTransactionsContinuously(from: date)
            .expectsAll(timeout: 2, on: self)
            .flatMap { $0 }
        XCTAssertFalse(transactions.isEmpty)
        
        for transaction in transactions {
            XCTAssertFalse(transaction.title.isEmpty)
            XCTAssertFalse(transaction.reference.isEmpty)
        }
    }
}
