import IG
import Decimals
import ConbiniForTesting
import XCTest

final class APIPositionTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests the position creation, confirmation, retrieval, and deletion.
    func testPositionLifecycle() {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let market = api.markets.get(epic: "CS.D.EURUSD.MINI.IP").expectsOne(timeout: 2, on: self)
        XCTAssertFalse(market.instrument.currencies.isEmpty)
        XCTAssertEqual(market.snapshot.status, .tradeable)
        XCTAssertFalse(market.instrument.currencies.isEmpty)
        let currency = market.instrument.currencies[0].code
        let reference = IG.Deal.Reference("TestBundle_" + UInt.random(in: 0...1_000_000).description)!
        
        // 1. Create a new market position.
        let referenceOpened = api.deals
            .createPosition(reference: reference, epic: market.instrument.epic, expiry: market.instrument.expiration.expiry, currency: currency, direction: .buy, order: .market, strategy: .execute, size: 1, limit: .distance(20), stop: .distance(20, risk: .exposed))
            .expectsOne(timeout: 2, on: self)
        XCTAssertEqual(referenceOpened, reference)
        // 1.1. Confirm the position has been opened.
        let confirmationOpened = api.deals
            .getConfirmation(reference: reference)
            .expectsOne(timeout: 2, on: self)
        XCTAssertLessThanOrEqual(confirmationOpened.date, Date())
        XCTAssertEqual(confirmationOpened.deal.status, .accepted)
        XCTAssertEqual(confirmationOpened.deal.reference, reference)
        XCTAssertEqual(confirmationOpened.details.epic, market.instrument.epic)
        XCTAssertEqual(confirmationOpened.details.expiry!, market.instrument.expiration.expiry)
        XCTAssertEqual(confirmationOpened.details.status!, .opened)
        
        // 2. Retrieve the position data.
        let position = api.deals
            .getPosition(id: confirmationOpened.deal.id)
            .expectsOne(timeout: 2, on: self)
        XCTAssertEqual(position.id, confirmationOpened.deal.id)
        XCTAssertEqual(position.reference, reference)
        XCTAssertNotNil(position.currency)
        XCTAssertEqual(position.currency, currency)
        XCTAssertEqual(position.size, confirmationOpened.details.size!)
        
        self.wait(seconds: 1)
        
        // 3. Update the position with new values.
        let referenceAmended = api.deals
            .updatePosition(id: position.id, limitLevel: nil, stop: nil)
            .expectsOne(timeout: 2, on: self)
        XCTAssertEqual(referenceAmended, reference)
        // 3.1. Confirm the position has been updated.
        let confirmationAmended = api.deals
            .getConfirmation(reference: reference)
            .expectsOne(timeout: 2, on: self)
        XCTAssertLessThanOrEqual(confirmationAmended.date, Date())
        XCTAssertEqual(confirmationAmended.deal.status, .accepted)
        XCTAssertEqual(confirmationAmended.deal.reference, reference)
        XCTAssertEqual(confirmationAmended.details.epic, market.instrument.epic)
        XCTAssertEqual(confirmationAmended.details.expiry!, market.instrument.expiration.expiry)
        XCTAssertEqual(confirmationAmended.details.status!, .amended)
        
        self.wait(seconds: 1)
        
        // 4. Close the position.
        let referenceClosed = api.deals
            .closePosition(matchedBy: .identifier(position.id), direction: position.direction.oppossite, order: .market, strategy: .execute, size: position.size)
            .expectsOne(timeout: 2, on: self)
        XCTAssertEqual(referenceClosed, reference)
        // 4.1. Confirm the position has been closed.
        let confirmationClosed = api.deals
            .getConfirmation(reference: reference)
            .expectsOne(timeout: 2, on: self)
        XCTAssertLessThanOrEqual(confirmationClosed.date, Date())
        XCTAssertEqual(confirmationClosed.deal.status, .accepted)
        XCTAssertEqual(confirmationClosed.deal.reference, reference)
        XCTAssertEqual(confirmationClosed.details.epic, market.instrument.epic)
        XCTAssertEqual(confirmationClosed.details.expiry!, market.instrument.expiration.expiry)
        XCTAssertEqual(confirmationClosed.details.status!, .closed(.fully))
    }
}
