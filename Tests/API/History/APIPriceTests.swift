import XCTest
import ReactiveSwift
@testable import IG

/// Tests API history activity related enpoints
final class APIPriceTests: APITestCase {
    /// Tests paginated activity retrieval.
    func testPrices() {
        let components = DateComponents().set {
            $0.timeZone = TimeZone(abbreviation: "CET")
            ($0.year, $0.month, $0.day) = (2019, 7, 1)
            ($0.hour, $0.minute) = (0, 0)
        }
        
        let calendar = Calendar(identifier: .gregorian)
        let fromDate = calendar.date(from: components)!
        let toDate = calendar.date(from: components.set { $0.minute = 59 })!
        
        let endpoint = self.api.prices.get(epic: "CS.D.EURUSD.MINI.IP", from: fromDate, to: toDate, resolution: .minutes10).on(value: {
            let prices = $0.prices
            XCTAssertFalse(prices.isEmpty)
            
            let element = prices[Int.random(in: 0..<prices.count)]
            XCTAssertGreaterThanOrEqual(element.date, fromDate)
            XCTAssertLessThanOrEqual(element.date, toDate)
        })
        
        self.test("Prices (history)", endpoint, signingProcess: .oauth, timeout: 10)
    }
}
