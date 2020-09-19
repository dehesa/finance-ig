import IG
import ConbiniForTesting
import XCTest

/// Tests API history activity related enpoints
final class APIActivityTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests paginated activity retrieval.
    func testActivities() {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let date = Date().lastTuesday
        let activities = api.accounts.getActivityContinuously(from: date, detailed: true)
            .expectsAll(timeout: 2, on: self)
            .flatMap { $0 }
        XCTAssertFalse(activities.isEmpty)
        
        for activity in activities {
            XCTAssertGreaterThan(activity.date, date)
            XCTAssertFalse(activity.summary.isEmpty)
        }
    }
}
