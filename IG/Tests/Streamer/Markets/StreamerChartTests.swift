import XCTest
import IG
import Combine

final class StreamerChartTests: XCTestCase {
    /// Tests subscription to candle charts.
    func testChartSecond() {
        let (rootURL, creds) = self.streamerCredentials(from: Test.account(environmentKey: "io.dehesa.money.ig.tests.account"))
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect().expectsCompletion(timeout: 2, on: self)
        XCTAssertTrue(streamer.status.isReady)
        
        let epic: IG.Market.Epic = "CS.D.EURGBP.MINI.IP"
        streamer.price.subscribe(epic: epic, interval: .second, fields: .all)
            .expectsAtLeast(values: 4, timeout: 8, on: self) { (second) in
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
            }
        
        streamer.session.disconnect().expectsCompletion(timeout: 2, on: self)
        XCTAssertEqual(streamer.status, .disconnected(isRetrying: false))
    }
    
    /// Tests subscription to tick charts.
    func testChartTick() {
        let (rootURL, creds) = self.streamerCredentials(from: Test.account(environmentKey: "io.dehesa.money.ig.tests.account"))
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect().expectsCompletion(timeout: 2, on: self)
        XCTAssertTrue(streamer.status.isReady)
        
        let epic: IG.Market.Epic = "CS.D.EURGBP.MINI.IP"
        streamer.price.subscribe(epic: epic, fields: .all)
            .expectsAtLeast(values: 4, timeout: 8, on: self) { (tick) in
                XCTAssertEqual(tick.epic, epic)
                XCTAssertEqual(tick.volume, 1)
                XCTAssertLessThanOrEqual(tick.date!, Date())
            }

        streamer.session.disconnect().expectsCompletion(timeout: 2, on: self)
        XCTAssertEqual(streamer.status, .disconnected(isRetrying: false))
    }
}
