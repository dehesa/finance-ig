import XCTest
import ReactiveSwift
@testable import IG

/// Tests API Application related endpoints.
final class APIApplicationTests: APITestCase {
    /// Tests the retrieval of all applications accessible by the given user.
    func testApplications() {
        let endpoint = self.api.applications().on(value: {
            XCTAssertFalse($0.isEmpty)
            
            let app = $0.first!
            XCTAssertFalse(app.name.isEmpty)
            XCTAssertFalse(app.apiKey.isEmpty)
            let allow = app.allowance
            XCTAssertGreaterThan(allow.requests.application, 0)
            XCTAssertGreaterThan(allow.requests.account.overall, 0)
            XCTAssertGreaterThan(allow.requests.account.trading, 0)
            XCTAssertGreaterThan(allow.requests.account.historicalData, 0)
            XCTAssertGreaterThan(allow.lightStreamer.concurrentSubscriptionsLimit, 0)
            XCTAssertLessThan(app.creationDate, Date())
            
            for app in $0 {
                print(app)
            }
        })
        
        self.test("Applications", endpoint, signingProcess: .oauth, timeout: 1)
    }
    
    /// Tests the application configuration capabilities.
    func testApplicationSettings() {
        let input: (status: API.Application.Status, overall: Int, trading: Int) = (.enabled, 30, 100)
        
        let endpoint = self.api.updateApplication(status: input.status, accountAllowance: (input.overall, input.trading)).on(value: {
            XCTAssertEqual($0.apiKey, (try! self.api.credentials()).apiKey)
            XCTAssertEqual($0.allowance.requests.account.overall, input.overall)
            XCTAssertEqual($0.allowance.requests.account.trading, input.trading)
        })
        
        self.test("Application settings", endpoint, signingProcess: .oauth, timeout: 1)
    }
}
