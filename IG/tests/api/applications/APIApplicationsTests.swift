import IG
import ConbiniForTesting
import XCTest

/// Tests API Application related endpoints.
final class APIApplicationTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let _acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests the retrieval of all applications accessible by the given user.
    func testApplications() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: self.apiCredentials(from: self._acc), targetQueue: nil)
        
        let applications = api.accounts.getApplications().expectsOne(timeout: 2, on: self)
        guard let app = applications.first else { return XCTFail("No applications were found") }
        XCTAssertEqual(app.key, self._acc.api.key)
        XCTAssertFalse(app.name.isEmpty)
        XCTAssertEqual(app.status, .enabled)
        XCTAssertLessThan(app.date, Date())
        XCTAssertGreaterThan(app.allowance.overallRequests, 0)
        XCTAssertGreaterThan(app.allowance.account.overallRequests, 0)
        XCTAssertGreaterThan(app.allowance.account.tradingRequests, 0)
        XCTAssertGreaterThan(app.allowance.account.historicalDataRequests, 0)
        XCTAssertGreaterThan(app.allowance.subscriptionsLimit, 0)
        XCTAssertLessThan(app.date, Date())
    }
    
    /// Tests the application configuration capabilities.
    func testApplicationSettings() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: self.apiCredentials(from: self._acc), targetQueue: nil)

        let status: API.Application.Status = .enabled
        let allowance: (overall: UInt, trading: UInt) = (60, 100)

        let app = api.accounts.updateApplication(key: self._acc.api.key, status: status, accountAllowance: allowance).expectsOne(timeout: 2, on: self)
        XCTAssertEqual(app.key, self._acc.api.key)
        XCTAssertEqual(app.status, status)
        XCTAssertEqual(app.allowance.account.overallRequests, Int(allowance.overall))
        XCTAssertEqual(app.allowance.account.tradingRequests, Int(allowance.trading))
    }
}
