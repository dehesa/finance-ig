import XCTest
import IG
import Combine

final class StreamerAccountTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let _acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Test Lightstreamer subscription to account changes.
    func testAccountSubscription() {
        let (rootURL, creds) = self.streamerCredentials(from: self._acc)
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect().expectsCompletion(timeout: 2, on: self)
        XCTAssertTrue(streamer.session.status.isReady)
        
        streamer.accounts.subscribe(account: self._acc.id, fields: .all)
            .expectsAtLeast(values: 1, timeout: 2, on: self) { (account) in
                XCTAssertEqual(account.id, self._acc.id)
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
