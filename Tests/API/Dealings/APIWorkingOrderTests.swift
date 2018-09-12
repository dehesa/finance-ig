import XCTest
import ReactiveSwift
@testable import IG

final class APIWorkingOrderTests: APITestCase {
    /// Tests the various open position retrieval endpoints.
    func testWorkingOrderRetrieval() {
        let endpoint = self.api.workingOrders().on(value: {
            XCTAssertFalse($0.isEmpty)
        })
        
        self.test("Position retrieval", endpoint, signingProcess: .oauth, timeout: 2)
    }
    
    /// Tests the working order lifecycle.
    func testWorkingOrderLifecycle() {
        let epic = "CS.D.EURUSD.MINI.IP"
        
        var storedReference: String!
        let endpoints = self.api.market(epic: epic).call(on: self.api) { (api, market) -> SignalProducer<String,API.Error> in
            let expiration = API.WorkingOrder.Expiration.tillCancelled
            let epic = market.instrument.epic
            let expiry = market.instrument.expiration.expiry
            let currency = market.instrument.currencies[0].code
            let size: Double = 1
            let direction: API.Position.Direction = .buy
            let type: API.WorkingOrder.Kind = .limit
            let level = market.snapshot.range.low - 0.005
            
            let creation = API.Request.WorkingOrder.Creation(expiration, epic: epic, expiry: expiry, currency: currency, size: size, direction: direction, level: level, type: type)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            return self.api.createWorkingOrder(creation)
        }.on(value: { (reference) in
            XCTAssertFalse(reference.isEmpty)
            storedReference = reference
        }).call(on: self.api) { (api, reference) -> SignalProducer<APIResponseConfirmation,API.Error> in
            api.confirmation(reference: reference)
        }.on(value: { (confirmation) in
            XCTAssertNotNil(confirmation.acceptedResponse)
            XCTAssertEqual(confirmation.reference, storedReference)
            XCTAssertFalse(confirmation.identifier.isEmpty)
        }).call(on: self.api) { (api, confirmation) -> SignalProducer<String,API.Error> in
            api.deleteWorkingOrder(identifier: confirmation.identifier)
        }.on(value: { (reference) in
            XCTAssertEqual(reference, storedReference)
        })
        
        self.test("Position lifecycle", endpoints, signingProcess: .oauth, timeout: 3)
    }
}
