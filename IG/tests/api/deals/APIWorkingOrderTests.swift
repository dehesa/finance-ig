import IG
import Decimals
import ConbiniForTesting
import XCTest

final class APIWorkingOrderTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let _acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Tests the working order lifecycle.
    func testWorkingOrderLifecycle() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: self.apiCredentials(from: self._acc), targetQueue: nil)

        let market = api.markets.get(epic: "CS.D.EURUSD.MINI.IP")
            .expectsOne(timeout: 2, on: self)
        let epic = market.instrument.epic
        let expiry = market.instrument.expiration.expiry
        let currency = market.instrument.currencies[0].code
        let type: IG.Deal.WorkingOrder = .limit
        let expiration: IG.Deal.WorkingOrder.Expiration = .tillDate(Date().addingTimeInterval(60 * 60 * 2))
        let direction: IG.Deal.Direction = .buy
        let size: Decimal64 = 1
        let level = market.snapshot.price!.lowest - (0.0001 * 30)
        let limitDistance: Decimal64 = 10
        let stopDistance: Decimal64 = 20
        let forceOpen: Bool = true
        //let scalingFactor: Decimal64 = 10000
        
        let reference = api.deals.createWorkingOrder(reference: nil, epic: epic, expiry: expiry, currency: currency, type: type, expiration: expiration, direction: direction, size: size, level: level, limit: .distance(limitDistance), stop: .distance(stopDistance, risk: .exposed), forceOpen: forceOpen)
            .expectsOne(timeout: 2, on: self)
        let confirmation = api.deals.confirm(reference: reference)
            .expectsOne(timeout: 2, on: self)
        let identifier = confirmation.deal.id
        XCTAssertEqual(confirmation.deal.reference, reference)
        XCTAssertEqual(confirmation.deal.status, .accepted)
        
        let orders = api.deals.getWorkingOrders()
            .expectsOne(timeout: 2, on: self)
        XCTAssertNotNil(orders.first { $0.identifier == identifier })

        let deleteReference = api.deals.deleteWorkingOrder(id: confirmation.deal.id)
            .expectsOne(timeout: 2, on: self)
        XCTAssertEqual(deleteReference, reference)
        let deleteConfirmation = api.deals.confirm(reference: deleteReference)
            .expectsOne(timeout: 2, on: self)
        XCTAssertEqual(deleteConfirmation.deal.status, .accepted)
    }
}
