import XCTest
import ReactiveSwift
@testable import IG

final class APIPositionTests: APITestCase {
    /// Tests the various open position retrieval endpoints.
    func testPositionRetrieval() {
        let endpoints = self.api.positions.getAll().on(value: {
            XCTAssertFalse($0.isEmpty)
        }).call(on: self.api) { (api, positions) -> SignalProducer<API.Position,API.Error> in
            let open = positions.first!
            return api.positions.get(identifier: open.identifier)
        }
        
        self.test("Position retrieval", endpoints, signingProcess: .oauth, timeout: 2)
    }
    
    /// Tests the position creation, confirmation, retrieval, and deletion.
    func testPositionLifecycle() {
        let epic: Epic = "CS.D.EURUSD.MINI.IP"
        let expiry: API.Expiry = nil
        let currency: Currency = "USD"
        let direction: API.Position.Direction = .sell
        let order: API.Position.Order = .market
        let strategy: API.Position.Order.Strategy = .execute
        let size: Double = 1
        let limitDistance: Double = 10
        let (stopDistance, stopIncrement) = (Double(20), Double(5))
        let stop: API.Request.Positions.Stop = .trailing(distance: stopDistance, increment: stopIncrement)
        let scalingFactor: Double = 10000
        
        var stored: (reference: API.Deal.Reference?, identifier: API.Deal.Identifier?) = (nil, nil)
        
        let endpoints = self.api.positions.create(epic: epic, expiry: expiry, currency: currency, direction: direction, order: order, strategy: strategy, size: size, limit: .distance(limitDistance), stop: stop)
            .call(on: self.api) { (api, reference) -> SignalProducer<API.Position.Confirmation,API.Error> in
                stored.reference = reference
                return api.positions.confirm(reference: reference)
            }.on(value: { (confirmation) in
                XCTAssertEqual(stored.reference!, confirmation.reference)
                stored.identifier = confirmation.identifier
                XCTAssertLessThan(confirmation.date, Date())
                XCTAssertEqual(epic, confirmation.epic)
                XCTAssertEqual(expiry, confirmation.expiry)
                
                guard case .accepted(let details) = confirmation.status else {
                    return XCTFail("The position confirmation failed.\n\tReference: \(confirmation.reference)\n\tIdentifier: \(confirmation.identifier)")
                }
                
                XCTAssertEqual(direction, details.direction)
                XCTAssertEqual(size, details.size)
                
                guard let limitLevel = details.limit else {
                    return XCTFail("The limit level has not been set.")
                }
                XCTAssertEqual(round(limitDistance), round(abs(details.level - limitLevel) * scalingFactor))
                
                guard case .trailing(let stopLevel, _) = details.stop else {
                    return XCTFail("The stop level couldn't be found")
                }
                
                XCTAssertEqual(round(stopDistance), round(abs(details.level - stopLevel) * scalingFactor))
                XCTAssertNil(details.profit)
            }).call(on: self.api) { (api, confirmation) -> SignalProducer<API.Position,API.Error> in
                api.positions.get(identifier: confirmation.identifier)
            }.call(on: self.api) { (api, position) -> SignalProducer<API.Deal.Reference,API.Error> in
                api.positions.delete(matchedBy: .identifier(position.identifier), direction: direction.oppossite, order: order, strategy: strategy, size: size)
            }.call(on: self.api) { (api, reference) -> SignalProducer<API.Position.Confirmation,API.Error> in
                api.positions.confirm(reference: reference)
            }.on(value: { (confirmation) in
                guard case .accepted(_) = confirmation.status else {
                    return XCTFail("The position couldn't be deleted.")
                }
            })

        self.test("Position lifecycle", endpoints, signingProcess: .oauth, timeout: 3)
    }
}
