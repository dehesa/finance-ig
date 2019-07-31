import XCTest
import ReactiveSwift
@testable import IG

/// Tests API Application related endpoints.
final class APIApplicationTests: XCTestCase {
    /// Tests the retrieval of all applications accessible by the given user.
    func testApplications() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        let applications = try! api.applications.getAll().single()!.get()
        
        guard let app = applications.first else { return XCTFail("No applications were found.") }
        XCTAssertFalse(app.name.isEmpty)
        XCTAssertEqual(app.apiKey, api.session.credentials!.apiKey)
        XCTAssertEqual(app.status, .enabled)
        XCTAssertLessThan(app.creationDate, Date())
        XCTAssertGreaterThan(app.allowance.requests.application, 0)
        XCTAssertGreaterThan(app.allowance.requests.account.overall, 0)
        XCTAssertGreaterThan(app.allowance.requests.account.trading, 0)
        XCTAssertGreaterThan(app.allowance.requests.account.historicalData, 0)
        XCTAssertGreaterThan(app.allowance.lightStreamer.concurrentSubscriptionsLimit, 0)
        XCTAssertLessThan(app.creationDate, Date())
    }
    
    /// Tests the application configuration capabilities.
    func testApplicationSettings() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        
        let apiKey = Test.account.api.key
        let status: API.Application.Status = .enabled
        let allowance: (overall: UInt, trading: UInt) = (30, 100)
        
        let app = try! api.applications.update(apiKey: apiKey, status: status, accountAllowance: allowance).single()!.get()
        XCTAssertEqual(app.apiKey, apiKey)
        XCTAssertEqual(app.status, status)
        XCTAssertEqual(app.allowance.requests.account.overall, allowance.overall)
        XCTAssertEqual(app.allowance.requests.account.trading, allowance.trading)
    }
}
