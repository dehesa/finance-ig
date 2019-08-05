import XCTest
import ReactiveSwift
@testable import IG

final class StreamerChartScaleTests: XCTestCase {
    func testChartSecond() {
        let scheduler = QueueScheduler(suffix: ".streamer.market.test")
        let streamer = Test.makeStreamer(autoconnect: .yes(timeout: 1.5, queue: scheduler))
        
        let epic: Epic = "CS.D.EURGBP.MINI.IP"
        let data = try! streamer.markets.subscribe(to: epic, aggregation: .second, .all, snapshot: true)
            .collect(count: 5)
            .take(first: 1)
            .timeout(after: 9, on: scheduler) { _ in .invalidRequest(message: "There was an error gathering the second chart data") }
            .single()!.get()
        
        for second in data {
            XCTAssertEqual(second.epic, epic)
            XCTAssertEqual(second.interval, .second)
            XCTAssertNotNil(second.day.highest)
        }
        
        let unsubscriptions = try! SignalProducer(streamer.session.unsubscribeAll())
            .collect()
            .timeout(after: 3, on: scheduler) { .invalidRequest(message: "There wasn't enough time to unsubscribe properly.\n\($0)") }
            .single()!.get()
        XCTAssertEqual(unsubscriptions.count, 1)
        
        let statuses = try! SignalProducer(streamer.session.disconnect())
            .collect()
            .timeout(after: 2, raising: .sessionExpired, on: scheduler)
            .single()!.get()
        XCTAssertNotNil(statuses.last)
        XCTAssertEqual(statuses.last!, .disconnected(isRetrying: false))
    }
}
