import XCTest
import ReactiveSwift
@testable import IG

final class StreamerAccountTests: XCTestCase {
    /// Test Lightstreamer subscription to account changes.
    func testAccountSubscription() {
        let scheduler = QueueScheduler(suffix: ".streamer.market.test")
        let streamer = Test.makeStreamer(autoconnect: .yes(timeout: 1.5, queue: scheduler))
        
        let accountIdentifier = Test.account.identifier
        self.test( streamer.accounts.subscribe(to: accountIdentifier, fields: .all, snapshot: true), value: { (account) in
            XCTAssertEqual(account.identifier, accountIdentifier)
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
            print(account)
        }, take: 1, timeout: 2, on: scheduler)
        
        self.test( streamer.session.unsubscribeAll(), take: 1, timeout: 2, on: scheduler) {
            XCTAssertEqual($0.count, 1)
        }
        
        self.test( streamer.session.disconnect(), timeout: 2, on: scheduler) {
            XCTAssertNotNil($0.last)
            XCTAssertEqual($0.last!, .disconnected(isRetrying: false))
        }
    }
}
