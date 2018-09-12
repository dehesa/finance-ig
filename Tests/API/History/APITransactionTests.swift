import XCTest
import Utils
import ReactiveSwift
@testable import IG

/// Tests API transaction retrieval
final class APITransactionTests: APITestCase {
    /// Tests paginated transaction retrieval.
    func testTransactions() {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents().set { (d) in
            d.timeZone = TimeZone(abbreviation: "CET")
            (d.year, d.month, d.day) = (2018, 6, 5)
            (d.hour, d.minute) = (11, 15)
        })!
        
        let endpoint = self.api.transactions(from: date).on(value: {
            XCTAssertFalse($0.isEmpty)
        })
        
        self.test("Transactions (history)", endpoint, signingProcess: .oauth, timeout: 1)
    }
}
