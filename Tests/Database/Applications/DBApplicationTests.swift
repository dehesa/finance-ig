@testable import IG
import ReactiveSwift
import XCTest

class DBApplicationTests: XCTestCase {
    /// Tests the creation of an "in-memory" database.
    func testApplicationsInMemory() {
        let api = Test.makeAPI(rootURL: Test.account.api.rootURL, credentials: Test.credentials.api, targetQueue: nil)
        let apiResponse = try! api.applications.getAll().single()!.get()
        XCTAssertFalse(apiResponse.isEmpty)

        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        try! db.applications.update(apiResponse).single()!.get()
        
        let dbResponse = try! db.applications.getAll().single()!.get()
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
            XCTAssertEqual(apiApp.creationDate, dbApp.created)
            XCTAssertLessThan(dbApp.updated, Date())
        }
    }
}
