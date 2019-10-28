@testable import IG
import XCTest

/// Tests API transaction retrieval
final class APITransactionTests: XCTestCase {
    /// Tests paginated transaction retrieval.
    func testTransactions() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
        let date = Calendar(identifier: .gregorian).date(from: DateComponents().set {
            $0.timeZone = TimeZone.current
            ($0.year, $0.month, $0.day) = (2019, 7, 1)
            ($0.hour, $0.minute) = (0, 0)
        })!
        
        let transactions = api.history.getTransactionsContinuously(from: date)
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
