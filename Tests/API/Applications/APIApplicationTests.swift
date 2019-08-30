@testable import IG
import ReactiveSwift
import XCTest

/// Tests API Application related endpoints.
final class APIApplicationTests: XCTestCase {
    /// Tests the retrieval of all applications accessible by the given user.
    func testApplications() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        let applications = try! api.applications.getAll().single()!.get()
        
        guard let app = applications.first else { return XCTFail("No applications were found.") }
        XCTAssertFalse(app.name.isEmpty)
        XCTAssertEqual(app.key, api.session.credentials!.key)
        XCTAssertEqual(app.status, .enabled)
        XCTAssertLessThan(app.creationDate, Date())
        XCTAssertGreaterThan(app.limits.overallRequests, 0)
        XCTAssertGreaterThan(app.limits.account.overallRequests, 0)
        XCTAssertGreaterThan(app.limits.account.tradingRequests, 0)
        XCTAssertGreaterThan(app.limits.account.historicalDataRequests, 0)
        XCTAssertGreaterThan(app.limits.subscriptionsLimit, 0)
        XCTAssertLessThan(app.creationDate, Date())
    }
    
    /// Tests the application configuration capabilities.
    func testApplicationSettings() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        
        let key = Test.account.api.key
        let status: API.Application.Status = .enabled
        let allowance: (overall: UInt, trading: UInt) = (30, 100)
        
        let app = try! api.applications.update(key: key, status: status, accountAllowance: allowance).single()!.get()
        XCTAssertEqual(app.key, key)
        XCTAssertEqual(app.status, status)
        XCTAssertEqual(app.limits.account.overallRequests, Int(allowance.overall))
        XCTAssertEqual(app.limits.account.tradingRequests, Int(allowance.trading))
    }
}
