import XCTest
import Utils
import ReactiveSwift
@testable import IG

/// Tests API history activity related enpoints
final class APIPriceTests: APITestCase {
    /// Tests paginated activity retrieval.
    func testPrices() {
        let dates: (from: Date, to: Date) = {
            let calendar = Calendar(identifier: .gregorian)
            
            var components = DateComponents().set { (c) in
                c.timeZone = TimeZone(abbreviation: "CET")
                (c.year, c.month, c.day, c.hour) = (2018, 5, 18, 21)
            }
            
            components.minute = 44
            let fromDate = calendar.date(from: components)!
            
            components.minute = 54
            let toDate = calendar.date(from: components)!
            
            return (fromDate, toDate)
        }()
        
        let endpoint = self.api.prices(epic: "CS.D.EURUSD.MINI.IP", from: dates.from, to: dates.to, resolution: .minute).on(value: {
            let prices = $0.prices
            XCTAssertFalse(prices.isEmpty)
            
            let element = prices[Int.random(in: 0..<prices.count)]
            XCTAssertGreaterThanOrEqual(element.snapshotDate, dates.from)
            XCTAssertLessThanOrEqual(element.snapshotDate, dates.to)
        })
        
        self.test("Activities (history)", endpoint, signingProcess: .oauth, timeout: 10)
    }
}
