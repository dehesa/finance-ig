@testable import IG
import ConbiniForTesting
import XCTest

/// Tests API history activity related enpoints
final class APIActivityTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Tests paginated activity retrieval.
    func testActivities() {
        let api = Test.makeAPI(rootURL: self.acc.api.rootURL, credentials: self.apiCredentials(from: self.acc), targetQueue: nil)
        
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
