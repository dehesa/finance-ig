import XCTest
import IG
import Combine

final class DBApplicationTests: XCTestCase {
    /// Tests the creation of an "in-memory" database.
    func testApplicationsInMemory() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        let apiResponse = api.applications.getAll().expectsOne { self.wait(for: [$0], timeout: 2) }
        XCTAssertFalse(apiResponse.isEmpty)
        
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        db.applications.update(apiResponse).expectsCompletion { self.wait(for: [$0], timeout: 2) }
        
        let dbResponse = db.applications.getAll().expectsOne { self.wait(for: [$0], timeout: 0.5) }
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

        for apiApp in apiResponse {
            let dbApp = db.applications.get(key: apiApp.key).expectsOne { self.wait(for: [$0], timeout: 0.5) }
            XCTAssertEqual(apiApp.key, dbApp.key)
        }
    }
    
    /// Tests the creation of an "in-memory" database.
    func testApplicationsEmpty() {
        let db = Test.makeDatabase(rootURL: nil, targetQueue: nil)
        db.applications.get(key: "a12345bc67890d12345e6789fg0hi123j4567890").expectsFailure { self.wait(for: [$0], timeout: 0.5) }
    }
}
