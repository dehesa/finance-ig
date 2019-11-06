@testable import IG
import XCTest

/// Tests API history activity related enpoints
final class APIActivityTests: XCTestCase {
    /// Tests paginated activity retrieval.
    func testActivities() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
        let date = Date().lastTuesday
        let activities = api.accounts.getActivityContinuously(from: date, detailed: true)
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
