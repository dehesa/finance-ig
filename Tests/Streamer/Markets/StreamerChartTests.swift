import XCTest
import ReactiveSwift
@testable import IG

final class StreamerChartTests: XCTestCase {
    /// Tests subscription to candle charts.
    func testChartSecond() {
        let scheduler = QueueScheduler(suffix: ".streamer.market.test")
        let rootURL = Test.account.streamer?.rootURL ?? Test.credentials.api.streamerURL
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: Test.credentials.streamer, targetQueue: nil, autoconnect: .yes(timeout: 1.5, queue: scheduler))
        
        let epic: IG.Market.Epic = "CS.D.EURGBP.MINI.IP"
        self.test( streamer.charts.subscribe(to: epic, interval: .second, fields: .all, snapshot: true), value: { (second) in
            XCTAssertEqual(second.epic, epic)
            XCTAssertEqual(second.interval, .second)
            XCTAssertNotNil(second.candle.date)
            XCTAssertNotNil(second.candle.numTicks)
            XCTAssertNotNil(second.candle.isFinished)
            XCTAssertNotNil(second.candle.open)
            XCTAssertNotNil(second.candle.close)
            XCTAssertNotNil(second.candle.lowest)
            XCTAssertNotNil(second.candle.highest)
            XCTAssertNotNil(second.day.lowest)
            XCTAssertNotNil(second.day.mid)
            XCTAssertNotNil(second.day.highest)
            XCTAssertNotNil(second.day.changeNet)
            XCTAssertNotNil(second.day.changePercentage)
        }, take: 3, timeout: 6, on: scheduler)
        
        self.test( streamer.session.unsubscribeAll(), take: 1, timeout: 2, on: scheduler) {
            XCTAssertEqual($0.count, 1)
        }
        
        self.test( streamer.session.disconnect(), timeout: 2, on: scheduler) {
            XCTAssertNotNil($0.last)
            XCTAssertEqual($0.last!, .disconnected(isRetrying: false))
        }
    }
    
    /// Tests subscription to tick charts.
    func testChartTick() {
        let scheduler = QueueScheduler(suffix: ".streamer.market.test")
        let rootURL = Test.account.streamer?.rootURL ?? Test.credentials.api.streamerURL
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: Test.credentials.streamer, targetQueue: nil, autoconnect: .yes(timeout: 1.5, queue: scheduler))
        
        let epic: IG.Market.Epic = "CS.D.EURGBP.MINI.IP"
        self.test( streamer.charts.subscribe(to: epic, fields: .all, snapshot: true), value: { (tick) in
            XCTAssertEqual(tick.epic, epic)
            // Some values can be `nil` on updates (such as `.ask`)
            print(tick)
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
