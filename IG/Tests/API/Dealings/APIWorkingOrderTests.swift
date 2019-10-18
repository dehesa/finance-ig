import IG
import XCTest

final class APIWorkingOrderTests: XCTestCase {
    /// Tests the working order lifecycle.
    func testWorkingOrderLifecycle() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)

        let market = api.markets.get(epic: "CS.D.EURUSD.MINI.IP")
            .expectsOne { self.wait(for: [$0], timeout: 2) }
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
            .expectsOne { self.wait(for: [$0], timeout: 2) }
        let confirmation = api.confirm(reference: reference)
            .expectsOne { self.wait(for: [$0], timeout: 2) }
        let identifier = confirmation.dealIdentifier
        XCTAssertEqual(confirmation.dealReference, reference)
        XCTAssertTrue(confirmation.isAccepted)
        
        let orders = api.workingOrders.getAll()
            .expectsOne { self.wait(for: [$0], timeout: 2) }
        XCTAssertNotNil(orders.first { $0.identifier == identifier })

        let deleteReference = api.workingOrders.delete(identifier: confirmation.dealIdentifier)
            .expectsOne { self.wait(for: [$0], timeout: 2) }
        XCTAssertEqual(deleteReference, reference)
        let deleteConfirmation = api.confirm(reference: deleteReference)
            .expectsOne { self.wait(for: [$0], timeout: 2) }
        XCTAssertTrue(deleteConfirmation.isAccepted)
    }
}
