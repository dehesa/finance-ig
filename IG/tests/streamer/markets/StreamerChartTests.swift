import XCTest
import IG
import Combine

final class StreamerChartTests: XCTestCase {
    /// Tests subscription to candle charts.
    func testChartSecond() {
        let (rootURL, creds) = self.streamerCredentials(from: Test.account(environmentKey: Test.defaultEnvironmentKey))
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect().expectsCompletion(timeout: 2, on: self)
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
        
        streamer.session.connect().expectsCompletion(timeout: 2, on: self)
        XCTAssertTrue(streamer.session.status.isReady)
        
        let epic: IG.Market.Epic = "CS.D.EURGBP.MINI.IP"
        streamer.prices.subscribe(epic: epic, fields: .all)
            .expectsAtLeast(values: 4, timeout: 8, on: self) { (tick) in
                XCTAssertEqual(tick.epic, epic)
                XCTAssertEqual(tick.volume, 1)
                XCTAssertLessThanOrEqual(tick.date!, Date())
            }

        streamer.session.disconnect().expectsOne(timeout: 2, on: self)
        XCTAssertEqual(streamer.session.status, .disconnected(isRetrying: false))
    }
    
    /// Test multiple connection for several minutes.
    func testRegularUsage() {
        let (rootURL, creds) = self.streamerCredentials(from: Test.account(environmentKey: Test.defaultEnvironmentKey))
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect().expectsCompletion(timeout: 2, on: self)
        XCTAssertTrue(streamer.session.status.isReady)
        
        let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
        
        let totalCount = Self.epics.count
        var marker = Date.distantPast
        var fullMinutes = 0
        var cache: [IG.Market.Epic] = []; cache.reserveCapacity(totalCount)
        
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
        
        let expectation = self.expectation(description: "3 full minutes for all markets")
        let cancellable = Self.epics.publisher
            .setFailureType(to: IG.Error.self)
            .flatMap {
                streamer.prices.subscribe(epic: $0, interval: .minute, fields: [.date, .isFinished, .numTicks, .openBid, .openAsk, .closeBid, .closeAsk, .lowestBid, .lowestAsk, .highestBid, .highestAsk], snapshot: true)
                    .retry(2)
            }.filter { $0.candle.isFinished ?? false }
            .sink(receiveCompletion: { _ in
                XCTFail("The publisher shall never complete")
            }, receiveValue: { (package) in
                guard let date = package.candle.date else { return XCTFail("\(package.epic) didn't have a date!") }
                let string: String
                
                os_unfair_lock_lock(lock)
                switch marker.compare(date) {
                case .orderedSame:
                    cache.append(package.epic)
                    string = "\t\(cache.count)"
                case .orderedAscending:
                    string = formatter.string(from: marker) + " \(cache.count) epics"
                    if cache.count == totalCount {
                        fullMinutes += 1
                        if fullMinutes >= 3 {
                            os_unfair_lock_unlock(lock)
                            return expectation.fulfill()
                        }
                    }
                    
                    marker = date
                    cache.removeAll()
                    cache.append(package.epic)
                case .orderedDescending:
                    fatalError("The date was previous in time!!")
                }
                os_unfair_lock_unlock(lock)
                
                print(string)
            })
        
        self.wait(for: [expectation], timeout: 60 * 5)
        cancellable.cancel()
        lock.deinitialize(count: 1)
        lock.deallocate()
        
        streamer.session.disconnect().expectsCompletion(timeout: 1, on: self)
    }
}

private extension StreamerChartTests {
    static var epics: Set<IG.Market.Epic> {
        ["CS.D.USDCAD.MINI.IP", "CS.D.GBPUSD.MINI.IP", "CS.D.EURUSD.MINI.IP", "CS.D.USDCHF.MINI.IP", "CS.D.USDJPY.MINI.IP", "CS.D.AUDUSD.MINI.IP", "CS.D.NZDUSD.MINI.IP", "CS.D.GBPCAD.MINI.IP", "CS.D.EURCAD.MINI.IP", "CS.D.CADCHF.MINI.IP", "CS.D.CADJPY.MINI.IP", "CS.D.AUDCAD.MINI.IP", "CS.D.NZDCAD.MINI.IP", "CS.D.GBPEUR.MINI.IP", "CS.D.GBPCHF.MINI.IP", "CS.D.GBPJPY.MINI.IP", "CS.D.AUDGBP.MINI.IP", "CS.D.NZDGBP.MINI.IP", "CS.D.EURCHF.MINI.IP", "CS.D.EURJPY.MINI.IP", "CS.D.EURAUD.MINI.IP", "CS.D.EURNZD.MINI.IP", "CS.D.CHFJPY.MINI.IP", "CS.D.AUDCHF.MINI.IP", "CS.D.NZDCHF.MINI.IP", "CS.D.AUDJPY.MINI.IP", "CS.D.NZDJPY.MINI.IP", "CS.D.AUDNZD.MINI.IP"]
    }
}
