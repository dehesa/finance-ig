import IG
import Decimals
import ConbiniForTesting
import XCTest

final class APIPositionTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let _acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Tests the position creation, confirmation, retrieval, and deletion.
    func testPositionLifecycle() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: self.apiCredentials(from: self._acc), targetQueue: nil)
        
        let epic: IG.Market.Epic = "CS.D.EURUSD.MINI.IP"
        let expiry: IG.Market.Expiry = .none
        let currency: Currency.Code = "USD"
        let direction: IG.Deal.Direction = .sell
        let order: API.Request.Deals.Position.Order = .market
        let strategy: API.Request.Deals.Position.FillStrategy = .execute
        let size: Decimal64 = 1
        let limit: IG.Deal.Boundary = .distance(10)!
        let stop: API.Request.Deals.Position.Stop = .trailing(distance: 20, increment: 5)
        //let scalingFactor: Double = 10000
        
        let reference = api.deals.createPosition(reference: nil, epic: epic, expiry: expiry, currency: currency, direction: direction, order: order, strategy: strategy, size: size, limit: limit, stop: stop)
            .expectsOne(timeout: 2, on: self)
        let creationConfirmation = api.deals.confirm(reference: reference)
            .expectsOne(timeout: 2, on: self)
        XCTAssertEqual(reference, creationConfirmation.deal.reference)
        XCTAssertLessThan(creationConfirmation.date, Date())
        XCTAssertEqual(epic, creationConfirmation.details.epic)
        XCTAssertEqual(expiry, creationConfirmation.details.expiry)
        let identifier = creationConfirmation.deal.id
        
        guard case .accepted = creationConfirmation.deal.status else {
            return XCTFail("The position confirmation failed.\n\tReference: \(creationConfirmation.deal.reference)\n\tIdentifier: \(creationConfirmation.deal.id)")
        }
        XCTAssertEqual(direction, creationConfirmation.details.direction)
        XCTAssertEqual(size, creationConfirmation.details.size)
        XCTAssertNotNil(creationConfirmation.details.limit)
        XCTAssertNotNil(creationConfirmation.details.stop)
        
        let _ = api.deals.getPosition(id: identifier)
            .expectsOne(timeout: 2, on: self)
        let deletionReference = api.deals.closePosition(matchedBy: .identifier(identifier), direction: direction.oppossite, order: order, strategy: strategy, size: size)
            .expectsOne(timeout: 2, on: self)
        let deletionConfirmation = api.deals.confirm(reference: deletionReference)
            .expectsOne(timeout: 2, on: self)
        XCTAssertEqual(deletionConfirmation.deal.status, .accepted)
    }
}
