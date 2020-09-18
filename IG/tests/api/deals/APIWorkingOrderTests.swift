import IG
import Decimals
import ConbiniForTesting
import XCTest

final class APIWorkingOrderTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests the working order lifecycle.
    func testWorkingOrderLifecycle() {
        let api = API()
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let market = api.markets.get(epic: "CS.D.EURUSD.MINI.IP").expectsOne(timeout: 2, on: self)
        XCTAssertFalse(market.instrument.currencies.isEmpty)
        XCTAssertEqual(market.snapshot.status, .tradeable)
        XCTAssertFalse(market.instrument.currencies.isEmpty)
        let currency = market.instrument.currencies[0].code
        let level = market.snapshot.price!.mid! - (80 / market.snapshot.scalingFactor)
        let expiration = Date(timeIntervalSinceNow: 5 * 60)
        let reference = IG.Deal.Reference("TestBundle_" + UInt.random(in: 0...1_000_000).description)!

        // 1. Create a new working order.
        let referenceOpened = api.deals
            .createWorkingOrder(reference: reference, epic: market.instrument.epic, expiry: market.instrument.expiration.expiry, currency: currency, direction: .buy, type: .limit, expiration: .tillDate(expiration), size: 1, level: level, limit: nil, stop: nil)
            .expectsOne(timeout: 2, on: self)
        XCTAssertEqual(referenceOpened, reference)
        // 1.1. Confirm the order has been created.
        let confirmationOpened = api.deals
            .getConfirmation(reference: reference)
            .expectsOne(timeout: 2, on: self)
        XCTAssertLessThanOrEqual(confirmationOpened.date, Date())
        XCTAssertEqual(confirmationOpened.deal.status, .accepted)
        XCTAssertEqual(confirmationOpened.deal.reference, reference)
        XCTAssertEqual(confirmationOpened.details.epic, market.instrument.epic)
        XCTAssertEqual(confirmationOpened.details.expiry!, market.instrument.expiration.expiry)
        XCTAssertEqual(confirmationOpened.details.status!, .opened)
        
        // 2. Retrieve the working order data.
        let order = api.deals
            .getWorkingOrders()
            .compactMap { $0.filter { $0.id == confirmationOpened.deal.id }.first }
            .expectsOne(timeout: 2, on: self)
        XCTAssertEqual(order.id, confirmationOpened.deal.id)
        XCTAssertLessThanOrEqual(order.date, Date())
        XCTAssertEqual(order.epic, market.instrument.epic)
        guard case .tillDate = order.expiration else { return XCTFail() }
        
        self.wait(seconds: 1)
        
        // 3. Update the working order with new values.
        let referenceAmended = api.deals
            .updateWorkingOrder(id: order.id, type: order.type, expiration: .tillCancelled, level: order.level, limit: .distance(20), stop: .distance(20))
            .expectsOne(timeout: 2, on: self) // The amended reference is different than the original reference
        // 3.1. Confirm the working order has been updated.
        let confirmationAmended = api.deals
            .getConfirmation(reference: referenceAmended)
            .expectsOne(timeout: 2, on: self)
        XCTAssertLessThanOrEqual(confirmationAmended.date, Date())
        XCTAssertEqual(confirmationAmended.deal.status, .accepted)
        XCTAssertEqual(confirmationAmended.deal.reference, referenceAmended)
        XCTAssertEqual(confirmationAmended.details.epic, market.instrument.epic)
        XCTAssertEqual(confirmationAmended.details.expiry!, market.instrument.expiration.expiry)
        XCTAssertEqual(confirmationAmended.details.status!, .amended)
        
        self.wait(seconds: 1)
        
        // 4 Delete the working order.
        let referenceDeleted = api.deals
            .deleteWorkingOrder(id: confirmationAmended.deal.id)
            .expectsOne(timeout: 2, on: self)
        // 4.1 Confirm the working order has been deleted.
        let confirmationDeleted = api.deals
            .getConfirmation(reference: referenceDeleted)
            .expectsOne(timeout: 2, on: self)
        XCTAssertLessThanOrEqual(confirmationDeleted.date, Date())
        XCTAssertEqual(confirmationDeleted.deal.status, .accepted)
        XCTAssertEqual(confirmationDeleted.details.epic, market.instrument.epic)
        XCTAssertEqual(confirmationDeleted.details.expiry!, market.instrument.expiration.expiry)
        XCTAssertEqual(confirmationDeleted.details.status!, .deleted)
    }
}
