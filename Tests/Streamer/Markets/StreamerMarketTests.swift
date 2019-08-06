import XCTest
import ReactiveSwift
@testable import IG

final class StreamerMarketTests: XCTestCase {
    /// Tests the market info subscription.
    func testMarketSubscriptions() {
        let scheduler = QueueScheduler(suffix: ".streamer.market.test")
        let streamer = Test.makeStreamer(autoconnect: .yes(timeout: 1.5, queue: scheduler))

        let epic: Epic = "CS.D.EURGBP.MINI.IP"
        self.test( streamer.markets.subscribe(to: epic, fields: .all), value: { (market) in
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
        }, take: 3, timeout: 6, on: scheduler)
        
        self.test( streamer.session.unsubscribeAll(), take: 1, timeout: 2, on: scheduler) {
            XCTAssertEqual($0.count, 1)
        }
        
        self.test( streamer.session.disconnect(), timeout: 2, on: scheduler) {
            XCTAssertNotNil($0.last)
            XCTAssertEqual($0.last!, .disconnected(isRetrying: false))
        }
    }
}
