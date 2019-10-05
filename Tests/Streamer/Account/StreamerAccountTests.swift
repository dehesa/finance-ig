import XCTest
import Combine
@testable import IG

final class StreamerAccountTests: XCTestCase {
    /// Test Lightstreamer subscription to account changes.
    func testAccountSubscription() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let (rootURL, creds) = self.streamerCredentials(from: acc)
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect().expectsAll { self.wait(for: [$0], timeout: 2) }
        XCTAssertTrue(streamer.status.isReady)
        
        streamer.accounts.subscribe(to: acc.identifier, fields: .all)
            .expectsAtLeast(1, each: { (account) in
                XCTAssertEqual(account.identifier, acc.identifier)
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
            }) { self.wait(for: [$0], timeout: 2) }
        
        streamer.session.unsubscribeAll()
            .expectsAll { self.wait(for: [$0], timeout: 2) }
        
        streamer.session.disconnect()
            .expectsAll { self.wait(for: [$0], timeout: 2) }
        XCTAssertEqual(streamer.status, .disconnected(isRetrying: false))
    }
}
