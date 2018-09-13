import XCTest
import ReactiveSwift
@testable import IG

/// Tests API transaction retrieval
final class APITransactionTests: APITestCase {
    /// Tests paginated transaction retrieval.
    func testTransactions() {
        var components = DateComponents()
        components.timeZone = TimeZone(abbreviation: "CET")
        (components.year, components.month, components.day) = (2018, 6, 5)
        (components.hour, components.minute) = (11, 15)
        
        let date = Calendar(identifier: .gregorian).date(from: components)!
        
        let endpoint = self.api.transactions(from: date).on(value: {
            XCTAssertFalse($0.isEmpty)
        })
        
        self.test("Transactions (history)", endpoint, signingProcess: .oauth, timeout: 1)
    }
}
