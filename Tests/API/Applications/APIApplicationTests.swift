import IG
import XCTest

/// Tests API Application related endpoints.
final class APIApplicationTests: XCTestCase {
    /// Tests the retrieval of all applications accessible by the given user.
    func testApplications() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: acc.api.credentials, targetQueue: nil)
        
        let applications = api.applications.getAll().waitForOne()
        guard let app = applications.first else { return XCTFail("No applications were found") }
        XCTAssertEqual(app.key, acc.api.key)
        XCTAssertFalse(app.name.isEmpty)
        XCTAssertEqual(app.status, .enabled)
        XCTAssertLessThan(app.creationDate, Date())
        XCTAssertGreaterThan(app.allowance.overallRequests, 0)
        XCTAssertGreaterThan(app.allowance.account.overallRequests, 0)
        XCTAssertGreaterThan(app.allowance.account.tradingRequests, 0)
        XCTAssertGreaterThan(app.allowance.account.historicalDataRequests, 0)
        XCTAssertGreaterThan(app.allowance.subscriptionsLimit, 0)
        XCTAssertLessThan(app.creationDate, Date())
    }
    
    /// Tests the application configuration capabilities.
    func testApplicationSettings() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: acc.api.credentials, targetQueue: nil)

        let status: API.Application.Status = .enabled
        let allowance: (overall: UInt, trading: UInt) = (60, 100)

        let app = api.applications.update(key: acc.api.key, status: status, accountAllowance: allowance).waitForOne()
        XCTAssertEqual(app.key, acc.api.key)
        XCTAssertEqual(app.status, status)
        XCTAssertEqual(app.allowance.account.overallRequests, Int(allowance.overall))
        XCTAssertEqual(app.allowance.account.tradingRequests, Int(allowance.trading))
    }
}
