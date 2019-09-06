@testable import IG
import ReactiveSwift
import XCTest

final class APIPositionTests: XCTestCase {
    /// Tests the position creation, confirmation, retrieval, and deletion.
    func testPositionLifecycle() {
        let api = Test.makeAPI(rootURL: Test.account.api.rootURL, credentials: Test.credentials.api, targetQueue: nil)
        
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
        
        let reference = try! api.positions.create(epic: epic, expiry: expiry, currency: currency, direction: direction, order: order, strategy: strategy, size: size, limit: limit, stop: stop).single()!.get()
        let creationConfirmation = try! api.confirm(reference: reference).single()!.get()
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
        
        let _ = try! api.positions.get(identifier: identifier).single()!.get()
        let deletionReference = try! api.positions.delete(matchedBy: .identifier(identifier), direction: direction.oppossite, order: order, strategy: strategy, size: size).single()!.get()
        let deletionConfirmation = try! api.confirm(reference: deletionReference).single()!.get()
        XCTAssertTrue(deletionConfirmation.isAccepted)
    }
}
