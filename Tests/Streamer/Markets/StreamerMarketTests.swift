import XCTest
import IG
import Combine

final class StreamerMarketTests: XCTestCase {
    #warning("Tests: Complete all Streamer tests")
    /// Tests the market info subscription.
    func testMarketSubscriptions() {
        let (rootURL, creds) = self.streamerCredentials(from: Test.account(environmentKey: "io.dehesa.money.ig.tests.account"))
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect()
            .expectsAll { self.wait(for: [$0], timeout: 2) }
        XCTAssertTrue(streamer.status.isReady)

        let epic: IG.Market.Epic = "CS.D.EURGBP.MINI.IP"
        streamer.markets.subscribe(to: epic, fields: .all)
            .expectsAtLeast(3, each: { (market) in
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
            }) { self.wait(for: [$0], timeout: 6) }
        
        streamer.session.unsubscribeAll()
            .expectsAll { self.wait(for: [$0], timeout: 2) }
        
        streamer.session.disconnect()
            .expectsAll { self.wait(for: [$0], timeout: 2) }
        XCTAssertEqual(streamer.status, .disconnected(isRetrying: false))
    }
}
