@testable import IG
import ReactiveSwift
import XCTest

/// Tests API transaction retrieval
final class APITransactionTests: XCTestCase {
    /// Tests paginated transaction retrieval.
    func testTransactions() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        
        let date = Calendar(identifier: .gregorian).date(from: DateComponents().set {
            $0.timeZone = TimeZone.current
            ($0.year, $0.month, $0.day) = (2019, 7, 1)
            ($0.hour, $0.minute) = (0, 0)
        })!
        
        let transactions = (try! api.history.getTransactions(from: date).collect().single()!.get()).flatMap { $0 }
        XCTAssertFalse(transactions.isEmpty)
        XCTAssertNil(transactions.first(where: { $0.title.isEmpty || $0.reference.isEmpty }))
    }
}
