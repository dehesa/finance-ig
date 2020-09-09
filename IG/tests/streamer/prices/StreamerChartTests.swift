import XCTest
import IG
import Combine

final class StreamerChartTests: XCTestCase {
    /// Tests subscription to candle charts.
    func testChartSecond() {
        let (rootURL, creds) = self.streamerCredentials(from: Test.account(environmentKey: Test.defaultEnvironmentKey))
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect().expectsCompletion(timeout: 5, on: self)
        XCTAssertTrue(streamer.session.status.isReady)
        
        let epic: IG.Market.Epic = "CS.D.EURGBP.MINI.IP"
        streamer.prices.subscribe(epic: epic, interval: .second, fields: .all)
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
        
        streamer.session.disconnect().expectsOne(timeout: 2, on: self)
        XCTAssertEqual(streamer.session.status, .disconnected(isRetrying: false))
    }
    
    /// Tests subscription to tick charts.
    func testChartTick() {
        let (rootURL, creds) = self.streamerCredentials(from: Test.account(environmentKey: Test.defaultEnvironmentKey))
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect().expectsCompletion(timeout: 5, on: self)
        XCTAssertTrue(streamer.session.status.isReady)
        
        let epic: IG.Market.Epic = "CS.D.EURGBP.MINI.IP"
        streamer.prices.subscribe(epic: epic, fields: .all)
            .expectsAtLeast(values: 4, timeout: 10, on: self) { (tick) in
                XCTAssertEqual(tick.epic, epic)
                XCTAssertEqual(tick.volume, 1)
                XCTAssertLessThanOrEqual(tick.date!, Date())
            }

        streamer.session.disconnect().expectsOne(timeout: 2, on: self)
        XCTAssertEqual(streamer.session.status, .disconnected(isRetrying: false))
    }
    
    /// Tests the subscription to multiple markets.
    func testMultipleChartAggregates() {
        let (rootURL, creds) = self.streamerCredentials(from: Test.account(environmentKey: Test.defaultEnvironmentKey))
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect().expectsCompletion(timeout: 5, on: self)
        XCTAssertTrue(streamer.session.status.isReady)
        
        let formatter = DateFormatter().set { $0.dateFormat = "MM.dd HH:mm:ss" }
        let epics: Set<IG.Market.Epic> = ["CS.D.EURGBP.MINI.IP", "CS.D.EURUSD.MINI.IP", "CS.D.EURCAD.CFD.IP"]
        let cancellable = streamer.prices.subscribe(epics: epics, interval: .minute, fields: .candle).sink(receiveCompletion: {
                print("Subscription completed: \($0)")
            }, receiveValue: { (agg) in
                guard let date = agg.candle.date else { return print("\tnil - \(agg.epic)") }
                print("\(formatter.string(from: date)) - \(agg.epic)")
            })
        
        self.wait(seconds: 120)
        cancellable.cancel()
        streamer.session.disconnect().expectsOne(timeout: 2, on: self)
    }
}
