import XCTest
import ReactiveSwift
@testable import IG

/// Tests API history activity related enpoints
final class APIPriceTests: APITestCase {
    ///
    private let dates: (from: Date, to: Date) = {
        let calendar = Calendar(identifier: .gregorian)
        
        var components = DateComponents()
        components.timeZone = TimeZone(abbreviation: "CET")
        (components.year, components.month, components.day, components.hour) = (2019, 6, 7, 00)
        
        components.minute = 00
        let fromDate = calendar.date(from: components)!
        
        components.minute = 59
        let toDate = calendar.date(from: components)!
        
        return (fromDate, toDate)
    }()
    
    /// Tests paginated activity retrieval.
    func testPrices() {
        let endpoint = self.api.prices(epic: "CS.D.EURUSD.MINI.IP", from: dates.from, to: dates.to, resolution: .minutes10).on(value: {
            let prices = $0.prices
            XCTAssertFalse(prices.isEmpty)
            
            let element = prices[Int.random(in: 0..<prices.count)]
            XCTAssertGreaterThanOrEqual(element.snapshotDate, self.dates.from)
            XCTAssertLessThanOrEqual(element.snapshotDate, self.dates.to)
        })
        
        self.test("Activities (history)", endpoint, signingProcess: .oauth, timeout: 10)
    }
}
