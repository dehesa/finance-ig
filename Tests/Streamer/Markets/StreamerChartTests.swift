import XCTest
import IG
import Combine

final class StreamerChartTests: XCTestCase {
    /// Tests subscription to candle charts.
    func testChartSecond() {
        let (rootURL, creds) = self.streamerCredentials(from: Test.account(environmentKey: "io.dehesa.money.ig.tests.account"))
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect().expectsCompletion { self.wait(for: [$0], timeout: 2) }
        XCTAssertTrue(streamer.status.isReady)
        
        let epic: IG.Market.Epic = "CS.D.EURGBP.MINI.IP"
        streamer.charts.subscribe(to: epic, interval: .second, fields: .all)
            .expectsAtLeast(4, each: { (second) in
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
            }) { self.wait(for: [$0], timeout: 8) }
        
        streamer.session.disconnect().expectsCompletion { self.wait(for: [$0], timeout: 2) }
        XCTAssertEqual(streamer.status, .disconnected(isRetrying: false))
    }
    
    /// Tests subscription to tick charts.
    func testChartTick() {
        let (rootURL, creds) = self.streamerCredentials(from: Test.account(environmentKey: "io.dehesa.money.ig.tests.account"))
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect().expectsCompletion { self.wait(for: [$0], timeout: 2) }
        XCTAssertTrue(streamer.status.isReady)
        
        let epic: IG.Market.Epic = "CS.D.EURGBP.MINI.IP"
        streamer.charts.subscribe(to: epic, fields: .all)
            .expectsAtLeast(4, each: { (tick) in
                XCTAssertEqual(tick.epic, epic)
                XCTAssertEqual(tick.volume, 1)
                XCTAssertLessThanOrEqual(tick.date!, Date())
            }) { self.wait(for: [$0], timeout: 8) }

        streamer.session.disconnect().expectsCompletion { self.wait(for: [$0], timeout: 2) }
        XCTAssertEqual(streamer.status, .disconnected(isRetrying: false))
    }
}
