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
        let expiry: API.Instrument.Expiry = nil
        let currency: Currency.Code = "USD"
        let direction: API.Deal.Direction = .sell
        let order: API.Position.Order = .market
        let strategy: API.Position.Order.Strategy = .execute
        let size: Decimal = 1
        let limit: API.Deal.Limit = .distance(10)
        let stop: API.Deal.Stop = .trailing(20, increment: 5)
        let scalingFactor: Double = 10000
        
        var stored: (reference: API.Deal.Reference?, identifier: API.Deal.Identifier?) = (nil, nil)
        let endpoints = self.api.positions.create(epic: epic, expiry: expiry, currency: currency, direction: direction, order: order, strategy: strategy, size: size, limit: limit, stop: stop)
            .call(on: self.api) { (api, reference) -> SignalProducer<API.Confirmation,API.Error> in
                stored.reference = reference
                return api.confirm(reference: reference)
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
                
                guard let confirmationLimit = details.limit else {
                    return XCTFail("The limit has not been returned on the confirmation.")
                }
                
                guard let confirmationStop = details.stop else {
                    return XCTFail("The stop has not been returned on the confirmation.")
                }
                
                print(confirmationLimit)
                print(confirmationStop)
//                XCTAssertEqual(round(limitDistance), round(abs(details.level - limitLevel) * scalingFactor))
//
//                guard case .trailing(let stopLevel, _) = details.stop else {
//                    return XCTFail("The stop level couldn't be found")
//                }
                
//                XCTAssertEqual(round(stopDistance), round(abs(details.level - stopLevel) * scalingFactor))
                XCTAssertNil(details.profit)
            }).call(on: self.api) { (api, confirmation) -> SignalProducer<API.Position,API.Error> in
                api.positions.get(identifier: confirmation.identifier)
            }.call(on: self.api) { (api, position) -> SignalProducer<API.Deal.Reference,API.Error> in
                api.positions.delete(matchedBy: .identifier(position.identifier), direction: direction.oppossite, order: order, strategy: strategy, size: size)
            }.call(on: self.api) { (api, reference) -> SignalProducer<API.Confirmation,API.Error> in
                api.confirm(reference: reference)
            }.on(value: { (confirmation) in
                guard case .accepted(_) = confirmation.status else {
                    return XCTFail("The position couldn't be deleted.")
                }
            })

        self.test("Position lifecycle", endpoints, signingProcess: .oauth, timeout: 3)
    }
}
