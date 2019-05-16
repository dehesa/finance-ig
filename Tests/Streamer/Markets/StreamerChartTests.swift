import XCTest
import ReactiveSwift
@testable import IG

final class StreamerChartTests: StreamerTestCase {
    /// Typealias for the Mini Forex Market.
    private typealias F = Market.Forex.Mini
    
    /// Tests the stream chart tick subscription.
    func testChartTickSubscription() {
        /// The market being targeted for subscription
        let epic: Epic = F.EUR_USD
        /// The fields to be subscribed to.
        let fields: Set<Streamer.Request.Chart.Tick> = Set(Streamer.Request.Chart.Tick.allCases)
        
        let subscription = self.streamer.subscribe(chart: epic, fields: fields).on(value: {
            for field in fields {
                let value = $0[keyPath: field.keyPath] as Any?
                XCTAssertNotNil(value)
            }
            XCTAssertGreaterThanOrEqual(Date(), $0.date!)
        })
        
        let numValuesExpected = 3
        let timeout = TimeInterval(numValuesExpected * 3)
        self.test("Chart tick subscription", subscription, numValues: numValuesExpected, timeout: timeout)
    }
    
    /// Tests the subscription to several markets with the same signal.
    func testSeveralChartTickSubscription() {
        /// The markets being targeted for subscription.
        let epics: [Epic] = [F.EUR_USD, F.EUR_GBP, F.EUR_CAD]
        /// The fields to be subscribed to.
        let fields = Set(Streamer.Request.Market.allCases)
        
        let subscription = self.streamer.subscribe(markets: epics, fields: fields, autoconnect: false).on(value: { (epic, response) in
            XCTAssertFalse(epic.identifier.isEmpty)
            for field in fields {
                let value = response[keyPath: field.keyPath] as Any?
                XCTAssertNotNil(value)
            }
            XCTAssertGreaterThanOrEqual(Date(), response.date!)
        })
        
        let numValuesExpected = 8
        let timeout = TimeInterval(numValuesExpected * 2)
        self.test("Market subscription", subscription, numValues: numValuesExpected, timeout: timeout)
    }
}

//var result = """
//,{
//\"type\": \"update\",
//\"fields\": {
//"""
//
//for (key, value) in $0.values {
//    result.append("\n\t\t\"\(key.rawValue)\": ")
//    switch value {
//    case let double as Double:
//        result.append("\"\(double)\",")
//    case let date as Date:
//        result.append("\"\(String(date.timeIntervalSince1970*1000))\",")
//    default: break
//    }
//}
//
//result.append("\n\t}\n}")
//print(result)
