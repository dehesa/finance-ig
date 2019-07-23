import XCTest
import ReactiveSwift
@testable import IG

/// Tests API transaction retrieval
final class APITransactionTests: APITestCase {
    /// Tests paginated transaction retrieval.
    func testTransactions() {
        let components = DateComponents().set {
            $0.timeZone = TimeZone.current
            ($0.year, $0.month, $0.day) = (2019, 7, 1)
            ($0.hour, $0.minute) = (0, 0)
        }
        
        let date = Calendar(identifier: .gregorian).date(from: components)!
        
        var counter = 0
        let endpoint = self.api.transactions.get(from: date).on(completed: {
            XCTAssertGreaterThan(counter, 0)
        }, value: {
            counter += $0.count
        })
        
        self.test("Transactions (history)", endpoint, signingProcess: .oauth, timeout: 2)
    }
}
