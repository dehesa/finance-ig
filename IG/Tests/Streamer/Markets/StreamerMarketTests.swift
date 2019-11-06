import XCTest
import IG
import Combine

final class StreamerMarketTests: XCTestCase {
    /// Tests the market info subscription.
    func testMarketSubscriptions() {
        let (rootURL, creds) = self.streamerCredentials(from: Test.account(environmentKey: "io.dehesa.money.ig.tests.account"))
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect().expectsCompletion(timeout: 2, on: self)
        XCTAssertTrue(streamer.status.isReady)

        let epic: IG.Market.Epic = "CS.D.EURGBP.MINI.IP"
        streamer.markets.subscribe(epic: epic, fields: .all)
            .expectsAtLeast(values: 3, timeout: 6, on: self) { (market) in
                XCTAssertEqual(market.epic, epic)
                XCTAssertNotNil(market.status)
                XCTAssertNotNil(market.date)
                XCTAssertNotNil(market.isDelayed)
                XCTAssertNotNil(market.bid)
                XCTAssertNotNil(market.ask)
                XCTAssertNotNil(market.day.lowest)
                XCTAssertNotNil(market.day.mid)
                XCTAssertNotNil(market.day.highest)
                XCTAssertNotNil(market.day.changeNet)
                XCTAssertNotNil(market.day.changePercentage)
            }
        
        streamer.session.disconnect().expectsCompletion(timeout: 2, on: self)
        XCTAssertEqual(streamer.status, .disconnected(isRetrying: false))
    }
}
