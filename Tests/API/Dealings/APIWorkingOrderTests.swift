@testable import IG
import ReactiveSwift
import XCTest

final class APIWorkingOrderTests: XCTestCase {
    /// Tests the working order lifecycle.
    func testWorkingOrderLifecycle() {
        let api = Test.makeAPI(credentials: Test.credentials.api)

        let market = try! api.markets.get(epic: "CS.D.EURUSD.MINI.IP").single()!.get()
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
        
        let reference = try! api.workingOrders.create(epic: epic, expiry: expiry, currency: currency, direction: direction, type: type, size: size, level: level, limit: .distance(limitDistance), stop: (.distance(stopDistance), .exposed), forceOpen: forceOpen, expiration: expiration, reference: nil).single()!.get()
        let confirmation = try! api.confirm(reference: reference).single()!.get()
        let identifier = confirmation.identifier
        XCTAssertEqual(confirmation.reference, reference)
        XCTAssertTrue(confirmation.isAccepted)
        
        let orders = try! api.workingOrders.getAll().single()!.get()
        XCTAssertNotNil(orders.first { $0.identifier == identifier })

        let deleteReference = try! api.workingOrders.delete(identifier: confirmation.identifier).single()!.get()
        XCTAssertEqual(deleteReference, reference)
        let deleteConfirmation = try! api.confirm(reference: deleteReference).single()!.get()
        XCTAssertTrue(deleteConfirmation.isAccepted)
    }
}
