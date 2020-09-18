import XCTest
import IG
import Combine

final class DBApplicationTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests the creation of an "in-memory" database.
    func testApplicationsInMemory() throws {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let apiResponse = api.accounts.getApplications().expectsOne(timeout: 2, on: self)
        XCTAssertFalse(apiResponse.isEmpty)
        
        let db = try Database(location: .memory)
        db.accounts.update(applications: apiResponse).expectsCompletion(timeout: 2, on: self)
        
        let dbResponse = db.accounts.getApplications().expectsOne(timeout: 0.5, on: self)
        XCTAssertEqual(apiResponse.count, dbResponse.count)
        for (apiApp, dbApp) in zip(apiResponse, dbResponse) {
            XCTAssertEqual(apiApp.key, dbApp.key)
            XCTAssertEqual(apiApp.name, dbApp.name)
            XCTAssertEqual(apiApp.permission.accessToEquityPrices, dbApp.permission.accessToEquityPrices)
            XCTAssertEqual(apiApp.permission.areQuoteOrdersAllowed, dbApp.permission.areQuoteOrdersAllowed)
            XCTAssertEqual(apiApp.allowance.overallRequests, dbApp.allowance.overallRequests)
            XCTAssertEqual(apiApp.allowance.account.overallRequests, dbApp.allowance.account.overallRequests)
            XCTAssertEqual(apiApp.allowance.account.tradingRequests, dbApp.allowance.account.tradingRequests)
            XCTAssertEqual(apiApp.allowance.account.historicalDataRequests, dbApp.allowance.account.historicalDataRequests)
            XCTAssertEqual(apiApp.allowance.subscriptionsLimit, dbApp.allowance.concurrentSubscriptions)
            XCTAssertEqual(apiApp.date, dbApp.created)
            XCTAssertLessThan(dbApp.updated, Date())
        }

        for apiApp in apiResponse {
            let dbApp = db.accounts.getApplication(key: apiApp.key).expectsOne(timeout: 0.5, on: self)
            XCTAssertEqual(apiApp.key, dbApp.key)
        }
    }
    
    /// Tests the creation of an "in-memory" database.
    func testApplicationsEmpty() throws {
        let db = try Database(location: .memory)
        db.accounts.getApplication(key: "a12345bc67890d12345e6789fg0hi123j4567890").expectsFailure(timeout: 0.5, on: self)
    }
}
