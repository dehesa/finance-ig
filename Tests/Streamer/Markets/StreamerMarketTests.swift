import XCTest
import ReactiveSwift
@testable import IG

final class StreamerMarketTests: XCTestCase {
    func testMarketSubscriptions() {
        let scheduler = QueueScheduler(suffix: ".streamer.market.test")
        let streamer = Test.makeStreamer(autoconnect: .yes(timeout: 1.5, queue: scheduler))

        let epic: Epic = "CS.D.EURGBP.MINI.IP"
        let markets = try! streamer.markets.subscribe(to: epic, .all)
            .collect(count: 3)
            .take(first: 1)
            .timeout(after: 7, on: scheduler) { _ in return .invalidRequest(message: "There wasn't enough time to receive 3 values from the subscription.") }
            .single()!.get()

        for market in markets {
            XCTAssertEqual(market.epic, epic)
            XCTAssertNotNil(market.status)
            XCTAssertNotNil(market.date)
            XCTAssertNotNil(market.isDelayed)
            XCTAssertNotNil(market.bid)
            XCTAssertNotNil(market.ask)
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
