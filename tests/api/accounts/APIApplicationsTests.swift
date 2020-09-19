import IG
import ConbiniForTesting
import XCTest

/// Tests API Application related endpoints.
final class APIApplicationTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests the retrieval of all applications accessible by the given user.
    func testApplications() {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let applications = api.accounts.getApplications().expectsOne(timeout: 2, on: self)
        guard let app = applications.first else { return XCTFail("No applications were found") }
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
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let status: API.Application.Status = .enabled
        let allowance: (overall: UInt, trading: UInt) = (60, 100)

        let app = api.accounts.updateApplication(key: "<#API key#>", status: status, accountAllowance: allowance).expectsOne(timeout: 2, on: self)
        XCTAssertEqual(app.status, status)
        XCTAssertEqual(app.allowance.account.overallRequests, Int(allowance.overall))
        XCTAssertEqual(app.allowance.account.tradingRequests, Int(allowance.trading))
    }
}
