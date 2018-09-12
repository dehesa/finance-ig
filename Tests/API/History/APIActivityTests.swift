import XCTest
import Utils
import ReactiveSwift
@testable import IG

/// Tests API history activity related enpoints
final class APIActivityTests: APITestCase {
    /// Tests paginated activity retrieval.
    func testActivities() {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents().set { (d) in
            d.timeZone = TimeZone(abbreviation: "CET")
            (d.year, d.month, d.day) = (2018, 6, 5)
            (d.hour, d.minute) = (11, 15)
        })!
        
        let endpoint = self.api.activity(from: date, detailed: true).on(value: {
            XCTAssertFalse($0.isEmpty)
        })
        
        self.test("Activities (history)", endpoint, signingProcess: .oauth, timeout: 1)
    }
}
