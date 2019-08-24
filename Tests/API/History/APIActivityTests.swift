@testable import IG
import ReactiveSwift
import XCTest

/// Tests API history activity related enpoints
final class APIActivityTests: XCTestCase {
    /// Tests paginated activity retrieval.
    func testActivities() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        
        let date = Calendar(identifier: .gregorian).date(from: DateComponents().set {
            $0.timeZone = TimeZone.current
            ($0.year, $0.month, $0.day) = (2019, 7, 1)
            ($0.hour, $0.minute) = (0, 0)
        })!
        
        let activities = (try! api.history.getActivity(from: date, detailed: true).collect().single()!.get()).flatMap { $0 }
        XCTAssertFalse(activities.isEmpty)
        XCTAssertNil(activities.first(where: { $0.title.isEmpty || $0.details == nil }))
    }
}
