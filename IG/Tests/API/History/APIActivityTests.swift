@testable import IG
import XCTest

/// Tests API history activity related enpoints
final class APIActivityTests: XCTestCase {
    /// Tests paginated activity retrieval.
    func testActivities() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
        let date = Calendar(identifier: .gregorian).date(from: DateComponents().set {
            $0.timeZone = .current
            ($0.year, $0.month, $0.day) = (2019, 7, 1)
            ($0.hour, $0.minute) = (0, 0)
        })!
        
        let activities = api.history.getActivityContinuously(from: date, detailed: true)
            .expectsAll(timeout: 2, on: self)
            .flatMap { $0 }
        XCTAssertFalse(activities.isEmpty)
        
        for activity in activities {
            XCTAssertGreaterThan(activity.date, date)
            XCTAssertFalse(activity.title.isEmpty)
            XCTAssertFalse(activity.debugDescription.isEmpty)
        }
    }
}
