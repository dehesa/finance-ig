import XCTest
import IG
import Combine

final class StreamerAccountTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Test Lightstreamer subscription to account changes.
    func testAccountSubscription() {
        let (rootURL, creds) = self.streamerCredentials(from: self.acc)
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect().expectsCompletion(timeout: 2, on: self)
        XCTAssertTrue(streamer.status.isReady)
        
        streamer.accounts.subscribe(account: self.acc.identifier, fields: .all)
            .expectsAtLeast(values: 1, timeout: 2, on: self) { (account) in
                XCTAssertEqual(account.identifier, self.acc.identifier)
                XCTAssertNotNil(account.equity.value)
                XCTAssertNotNil(account.equity.used)
                XCTAssertNotNil(account.funds.value)
                XCTAssertNotNil(account.funds.cashAvailable)
                XCTAssertNotNil(account.funds.tradeAvailable)
                XCTAssertNotNil(account.funds.deposit)
                XCTAssertNotNil(account.margins.value)
                XCTAssertNotNil(account.margins.limitedRisk)
                XCTAssertNotNil(account.margins.nonLimitedRisk)
                XCTAssertNotNil(account.profitLoss.value)
                XCTAssertNotNil(account.profitLoss.limitedRisk)
                XCTAssertNotNil(account.profitLoss.nonLimitedRisk)
            }
        
        streamer.session.disconnect().expectsCompletion(timeout: 2, on: self)
        XCTAssertEqual(streamer.status, .disconnected(isRetrying: false))
    }
}
