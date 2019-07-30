import XCTest
import ReactiveSwift
@testable import IG

final class APIWorkingOrderTests: APITestCase {
    /// Tests the various open position retrieval endpoints.
    func testWorkingOrderRetrieval() {
        let endpoint = self.api.workingOrders.getAll().on(value: {
            XCTAssertFalse($0.isEmpty)
        })
        
        self.test("Position retrieval", endpoint, signingProcess: .certificate, timeout: 1)
    }
    
    /// Tests the working order lifecycle.
    func testWorkingOrderLifecycle() {
        var stored: (reference: API.Deal.Reference?, identifier: API.Deal.Identifier?) = (nil, nil)
        let endpoints = self.api.markets.get(epic: "CS.D.EURUSD.MINI.IP")
            .call(on: self.api) { (api, market) -> SignalProducer<API.Deal.Reference,API.Error> in
                let epic = market.instrument.epic
                let expiry = market.instrument.expiration.expiry
                let currency = market.instrument.currencies[0].code
                let direction: API.Deal.Direction = .buy
                let type: API.WorkingOrder.Kind = .limit
                let size: Decimal = 1
                let level = market.snapshot.price.lowest - (0.0001 * 30)
                let limitDistance: Decimal = 10
                let stopDistance: Decimal = 20
                let forceOpen: Bool = true
                let expiration: API.WorkingOrder.Expiration = .tillDate(Date().addingTimeInterval(60 * 60 * 2))
                //let scalingFactor: Decimal = 10000
                return self.api.workingOrders.create(epic: epic, expiry: expiry, currency: currency, direction: direction, type: type, size: size, level: level, limit: .distance(limitDistance), stop: (.distance(stopDistance), .exposed), forceOpen: forceOpen, expiration: expiration, reference: nil)
        }.on(value: { (reference) in
            stored.reference = reference
        }).call(on: self.api) { (api, reference) -> SignalProducer<API.Confirmation,API.Error> in
            api.confirm(reference: reference)
        }.on(value: { (confirmation) in
            guard case .accepted(_) = confirmation.status else {
                return XCTFail("The working order was rejected.")
            }
            
            XCTAssertEqual(confirmation.reference, stored.reference)
            stored.identifier = confirmation.identifier
        }).call(on: self.api) { (api, confirmation) -> SignalProducer<API.Deal.Reference,API.Error> in
            api.workingOrders.delete(identifier: confirmation.identifier)
        }.on(value: { (reference) in
            XCTAssertEqual(reference, stored.reference!)
        })

        self.test("Position lifecycle", endpoints, signingProcess: .oauth, timeout: 3)
    }
}
