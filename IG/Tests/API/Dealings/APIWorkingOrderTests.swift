import IG
import ConbiniForTesting
import XCTest

final class APIWorkingOrderTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Tests the working order lifecycle.
    func testWorkingOrderLifecycle() {
        let api = Test.makeAPI(rootURL: self.acc.api.rootURL, credentials: self.apiCredentials(from: self.acc), targetQueue: nil)

        let market = api.markets.get(epic: "CS.D.EURUSD.MINI.IP")
            .expectsOne(timeout: 2, on: self)
        let epic = market.instrument.epic
        let expiry = market.instrument.expiration.expiry
        let currency = market.instrument.currencies[0].code
        let direction: IG.Deal.Direction = .buy
        let type: API.WorkingOrder.Kind = .limit
        let size: Decimal = 1
        let level = market.snapshot.price!.lowest - (0.0001 * 30)
        let limitDistance: Decimal = 10
        let stopDistance: Decimal = 20
        let forceOpen: Bool = true
        let expiration: API.WorkingOrder.Expiration = .tillDate(Date().addingTimeInterval(60 * 60 * 2))
        //let scalingFactor: Decimal = 10000
        
        let reference = api.workingOrders.create(epic: epic, expiry: expiry, currency: currency, direction: direction, type: type, size: size, level: level, limit: .distance(limitDistance), stop: (.distance(stopDistance), .exposed), forceOpen: forceOpen, expiration: expiration, reference: nil)
            .expectsOne(timeout: 2, on: self)
        let confirmation = api.confirm(reference: reference)
            .expectsOne(timeout: 2, on: self)
        let identifier = confirmation.dealIdentifier
        XCTAssertEqual(confirmation.dealReference, reference)
        XCTAssertTrue(confirmation.isAccepted)
        
        let orders = api.workingOrders.getAll()
            .expectsOne(timeout: 2, on: self)
        XCTAssertNotNil(orders.first { $0.identifier == identifier })

        let deleteReference = api.workingOrders.delete(identifier: confirmation.dealIdentifier)
            .expectsOne(timeout: 2, on: self)
        XCTAssertEqual(deleteReference, reference)
        let deleteConfirmation = api.confirm(reference: deleteReference)
            .expectsOne(timeout: 2, on: self)
        XCTAssertTrue(deleteConfirmation.isAccepted)
    }
}
