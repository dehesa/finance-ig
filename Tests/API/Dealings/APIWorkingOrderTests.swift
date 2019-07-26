import XCTest
import ReactiveSwift
@testable import IG

final class APIWorkingOrderTests: APITestCase {
    /// Tests the various open position retrieval endpoints.
    func testWorkingOrderRetrieval() {
        let endpoint = self.api.workingOrders.getAll().on(value: {
            XCTAssertFalse($0.isEmpty)
        }).call(on: self.api) { (api, list) -> SignalProducer<API.Deal.Reference,API.Error> in
            api.workingOrders.delete(identifier: list.first!.identifier)
        }.on(value: {
            print($0)
        })
        
        self.test("Position retrieval", endpoint, signingProcess: .oauth, timeout: 2)
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
                let size: Double = 1
                let level = market.snapshot.price.lowest - 0.005
                let limitDistance: Double = 10
                let stopDistance: Double = 20
                let forceOpen: Bool = true
                let expiration: API.WorkingOrder.Expiration = .tillDate(Date().addingTimeInterval(60 * 60 * 2))
//                let scalingFactor: Double = 10000

            return self.api.workingOrders.create(epic: epic, expiry: expiry, currency: currency, direction: direction, type: type, size: size, level: level, limit: .distance(limitDistance), stop: .distance(stopDistance, isGuaranteed: false), forceOpen: forceOpen, expiration: expiration, reference: nil)
        }.on(value: { (reference) in
            print(reference)
            stored.reference = reference
        })
//            .call(on: self.api) { (api, reference) -> SignalProducer<APIResponseConfirmation,API.Error> in
//            api.confirmation(reference: reference)
//        }.on(value: { (confirmation) in
//            XCTAssertNotNil(confirmation.acceptedResponse)
//            XCTAssertEqual(confirmation.reference, storedReference)
//            XCTAssertFalse(confirmation.identifier.isEmpty)
//        }).call(on: self.api) { (api, confirmation) -> SignalProducer<String,API.Error> in
//            api.deleteWorkingOrder(identifier: confirmation.identifier)
//        }.on(value: { (reference) in
//            XCTAssertEqual(reference, storedReference)
//        })
//
        self.test("Position lifecycle", endpoints, signingProcess: .oauth, timeout: 3)
    }
}
