import XCTest
import ReactiveSwift
@testable import IG

/// Tests API history activity related enpoints
final class APIActivityTests: APITestCase {
    /// Tests paginated activity retrieval.
    func testActivities() {
        var components = DateComponents()
        components.timeZone = TimeZone(abbreviation: "CET")
        (components.year, components.month, components.day) = (2018, 6, 5)
        (components.hour, components.minute) = (11, 15)
        
        let date = Calendar(identifier: .gregorian).date(from: components)!
        
        let endpoint = self.api.activity(from: date, detailed: true).on(value: {
            XCTAssertFalse($0.isEmpty)
        })
        
        self.test("Activities (history)", endpoint, signingProcess: .oauth, timeout: 1)
    }
}
