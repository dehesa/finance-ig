import XCTest
import ReactiveSwift
@testable import IG

final class StreamerMarketTests: StreamerTestCase {
    /// Typealias for the Mini Forex Market.
    private typealias F = Market.Forex.Mini
    
    /// Tests the stream market subscription.
    func testMarketSubscription() {
        /// The market being targeted for subscription
        let epic: Epic = F.EUR_USD
        /// The fields to be subscribed to.
        let fields = Set(Streamer.Request.Market.allCases)

        let subscription = self.streamer.subscribe(market: epic, fields: fields, autoconnect: false).on(value: {
            XCTAssertNotNil($0.status)
            XCTAssertEqual($0.status!, Streamer.Response.Market.Status.tradable, "If the market is not tradeable, the test can't be performed")
            XCTAssertEqual(fields.count, $0.fields.received.count)
        })

        let numValuesExpected = 3
        let timeout = TimeInterval(numValuesExpected * 3)
        self.test("Market subscription", subscription, numValues: numValuesExpected, timeout: timeout)
    }

    /// Tests the subscription to several markets with the same signal.
    func testSeveralMarketSubscription() {
        /// The markets being targeted for subscription.
        let epics: [Epic] = [F.EUR_USD, F.EUR_GBP, F.EUR_CAD]
        /// The fields to be subscribed to.
        let fields = Set(Streamer.Request.Market.allCases)

        let subscription = self.streamer.subscribe(markets: epics, fields: fields, autoconnect: false).on(value: { (epic, response) in
            XCTAssertNotNil(response.status)
            XCTAssertEqual(response.status!, Streamer.Response.Market.Status.tradable, "If the market is not tradeable, the test can't be performed")
            XCTAssertEqual(fields.count, response.fields.received.count)
        })

        let numValuesExpected = 8
        let timeout = TimeInterval(numValuesExpected * 2)
        self.test("Market subscription", subscription, numValues: numValuesExpected, timeout: timeout)
    }
}
