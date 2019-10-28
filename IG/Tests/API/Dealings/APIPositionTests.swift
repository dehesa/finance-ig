import IG
import XCTest

final class APIPositionTests: XCTestCase {
    /// Tests the position creation, confirmation, retrieval, and deletion.
    func testPositionLifecycle() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: self.apiCredentials(from: acc), targetQueue: nil)
        
        let epic: IG.Market.Epic = "CS.D.EURUSD.MINI.IP"
        let expiry: IG.Market.Expiry = nil
        let currency: IG.Currency.Code = "USD"
        let direction: IG.Deal.Direction = .sell
        let order: API.Position.Order = .market
        let strategy: API.Position.Order.Strategy = .execute
        let size: Decimal = 1
        let limit: IG.Deal.Limit = .distance(10)!
        let stop: IG.Deal.Stop = .trailing(20, increment: 5)!
        //let scalingFactor: Double = 10000
        
        let reference = api.positions.create(epic: epic, expiry: expiry, currency: currency, direction: direction, order: order, strategy: strategy, size: size, limit: limit, stop: stop)
            .expectsOne(timeout: 2, on: self)
        let creationConfirmation = api.confirm(reference: reference)
            .expectsOne(timeout: 2, on: self)
        XCTAssertEqual(reference, creationConfirmation.dealReference)
        XCTAssertLessThan(creationConfirmation.date, Date())
        XCTAssertEqual(epic, creationConfirmation.epic)
        XCTAssertEqual(expiry, creationConfirmation.expiry)
        let identifier = creationConfirmation.dealIdentifier
        
        guard case .accepted(let details) = creationConfirmation.status else {
            return XCTFail("The position confirmation failed.\n\tReference: \(creationConfirmation.dealReference)\n\tIdentifier: \(creationConfirmation.dealIdentifier)")
        }
        XCTAssertEqual(direction, details.direction)
        XCTAssertEqual(size, details.size)
        XCTAssertNotNil(details.limit)
        XCTAssertNotNil(details.stop)
        
        let _ = api.positions.get(identifier: identifier)
            .expectsOne(timeout: 2, on: self)
        let deletionReference = api.positions.delete(matchedBy: .identifier(identifier), direction: direction.oppossite, order: order, strategy: strategy, size: size)
            .expectsOne(timeout: 2, on: self)
        let deletionConfirmation = api.confirm(reference: deletionReference)
            .expectsOne(timeout: 2, on: self)
        XCTAssertTrue(deletionConfirmation.isAccepted)
    }
}
