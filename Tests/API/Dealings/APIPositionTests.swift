import XCTest
import ReactiveSwift
@testable import IG

final class APIPositionTests: APITestCase {
    /// Tests the various open position retrieval endpoints.
    func testPositionRetrieval() {
        let endpoints = self.api.positions().on(value: {
            XCTAssertFalse($0.isEmpty)
        }).call(on: self.api) { (api, positions) -> SignalProducer<API.Response.Position,API.Error> in
            let open = positions.first!
            return api.position(id: open.identifier)
        }
        
        self.test("Position retrieval", endpoints, signingProcess: .oauth, timeout: 2)
    }
    
    /// Tests the position creation, confirmation, retrieval, and deletion.
    func testPositionLifecycle() {
        let epic = "CS.D.EURUSD.MINI.IP"
        let currency = "USD"
        let size: Double = 1
        let direction: API.Position.Direction = .buy

        var storedReference: String!
        let endpoints = self.api.createPosition(.init(marketOrder: .execute, epic: epic, currency: currency, size: size, direction: direction)).on(value: { (reference) in
            XCTAssertFalse(reference.isEmpty)
            storedReference = reference
        }).call(on: self.api) { (api, reference) in
            api.confirmation(reference: reference)
        }.on(value: { (confirmation) in
            XCTAssertNotNil(confirmation.acceptedResponse)
            XCTAssertEqual(confirmation.reference, storedReference)
            XCTAssertFalse(confirmation.identifier.isEmpty)
        }).call(on: self.api) { (api, confirmation) -> SignalProducer<String,API.Error> in
            let position = confirmation.acceptedResponse!
            return api.deletePositions(.init(.byIdentifier(position.identifier), marketOrder: .execute, size: size, direction: direction.oppossite))
        }.on(value: { (reference) in
            XCTAssertEqual(reference, storedReference)
        })

        self.test("Position lifecycle", endpoints, signingProcess: .oauth, timeout: 3)
    }
}
