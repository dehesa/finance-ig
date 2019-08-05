//import XCTest
//import ReactiveSwift
//@testable import IG
//
//final class StreamerTradeTests: StreamerTestCase {
//    /// Tests for the stream confirmation subscription.
//    func testAccountTrade() {
//        /// The account identifier being targeted.
//        let accountId = "ZEU91"
//        /// The fields to be subscribed to.
////        let fields = Set(Streamer.Request.Trade.allCases)
//        let fields: Set<Streamer.Request.Trade> = [.confirmations]
//        
//        let subscription = self.streamer.subscribe(account: accountId, updates: fields)
//        
//        let numValuesExpected = 3
//        let timeout = TimeInterval(numValuesExpected * 3)
//        self.test("Account Trading updates subscription", subscription, numValues: numValuesExpected, timeout: timeout)
//    }
//}
