import IG
import Combine
import XCTest

final class StreamerAccountTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Test Lightstreamer subscription to account changes.
    func testAccountSubscription() throws {
        let api = API()
        api.session.login(type: .certificate, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let creds = (api: try XCTUnwrap(api.session.credentials), streamer: try Streamer.Credentials(api.session.credentials))
        let streamer = Streamer(rootURL: creds.api.streamerURL, credentials: creds.streamer)
        
        streamer.session.connect().expectsCompletion(timeout: 2, on: self)
        XCTAssertTrue(streamer.session.status.isReady)
        
        streamer.accounts.subscribe(account: creds.api.account, fields: .all)
            .expectsAtLeast(values: 1, timeout: 2, on: self) { (account) in
                XCTAssertEqual(account.id, creds.api.account)
                XCTAssertNotNil(account.funds)
                XCTAssertNotNil(account.equity.value)
                XCTAssertNotNil(account.equity.used)
                XCTAssertNotNil(account.equity.cashAvailable)
                XCTAssertNotNil(account.equity.tradeAvailable)
                XCTAssertNotNil(account.margins.value)
                XCTAssertNotNil(account.margins.limitedRisk)
                XCTAssertNotNil(account.margins.nonLimitedRisk)
                XCTAssertNotNil(account.margins.deposit)
                XCTAssertNotNil(account.profitLoss.value)
                XCTAssertNotNil(account.profitLoss.limitedRisk)
                XCTAssertNotNil(account.profitLoss.nonLimitedRisk)
            }
        
        streamer.session.disconnect().expectsOne(timeout: 2, on: self)
        XCTAssertEqual(streamer.session.status, .disconnected(isRetrying: false))
    }
}
