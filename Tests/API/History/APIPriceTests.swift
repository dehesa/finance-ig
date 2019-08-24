@testable import IG
import ReactiveSwift
import XCTest

/// Tests API history activity related enpoints
final class APIPriceTests: XCTestCase {
    /// Tests paginated activity retrieval.
    func testPrices() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        
        let components = DateComponents().set {
            $0.timeZone = TimeZone(abbreviation: "CET")
            ($0.year, $0.month, $0.day) = (2019, 7, 1)
            ($0.hour, $0.minute) = (0, 0)
        }
        
        let calendar = Calendar(identifier: .gregorian)
        let fromDate = calendar.date(from: components)!
        let toDate = calendar.date(from: components.set { $0.minute = 59 })!
        
        let events = (try! api.history.getPrices(epic: "CS.D.EURUSD.MINI.IP", from: fromDate, to: toDate, resolution: .minute10).collect().single()!.get())
        XCTAssertFalse(events.isEmpty)
        
        let prices = events.flatMap { $0.prices }
        let allowance = events.map { $0.allowance }
        XCTAssertFalse(prices.isEmpty)
        XCTAssertFalse(allowance.isEmpty)
            
        let element = prices[Int.random(in: 0..<prices.count)]
        XCTAssertGreaterThanOrEqual(element.date, fromDate)
        XCTAssertLessThanOrEqual(element.date, toDate)
    }
}
