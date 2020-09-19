import IG
import Combine
import Conbini
import Decimals
import XCTest

final class StreamerPositionTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests the position creation, retrieval, amendment, and deletion receiving the confirmations in a subscription.
    func testPositionSubscriptionLifetime() throws {
        let api = API()
        api.session.login(type: .certificate, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let creds = (api: try XCTUnwrap(api.session.credentials), streamer: try Streamer.Credentials(api.session.credentials))
        let streamer = Streamer(rootURL: creds.api.streamerURL, credentials: creds.streamer)
        
        let market = api.markets.get(epic: "CS.D.EURUSD.MINI.IP").expectsOne(timeout: 2, on: self)
        XCTAssertFalse(market.instrument.currencies.isEmpty)
        XCTAssertEqual(market.snapshot.status, .tradeable)
        XCTAssertFalse(market.instrument.currencies.isEmpty)
        let currency = market.instrument.currencies[0].code
        
        // 1. Connect & subscribe.
        streamer.session.connect().expectsCompletion(timeout: 2, on: self)
        XCTAssertTrue(streamer.session.status.isReady)
        
        let queue = DispatchQueue(label: "Lock queue")
        var waiter: Waiter? = nil
        
        let cancellable = streamer.deals.subscribe(account: creds.api.account, fields: .all, snapshot: false)
            .sink(receiveCompletion: { _ in XCTFail() }, receiveValue: { (deal) in
                queue.sync { () -> XCTestExpectation? in
                    guard let w = waiter else { return nil }
                    
                    if let c = deal.confirmation, c.deal.reference == w.reference {
                        w.isConfirmationReceived = true
                    }
                    
                    if let u = deal.update, u.deal.reference == w.reference {
                        w.isUpdateReceived = true
                    }
                    
                    guard w.isUpdateReceived && w.isConfirmationReceived else { return nil }
                    waiter = nil
                    return w.expectation
                }?.fulfill()
            })
        self.wait(seconds: 1)
        
        // 2. Create a new market position
        let referenceOpened = api.deals
            .createPosition(epic: market.instrument.epic, currency: currency, direction: .buy, order: .market, strategy: .execute, size: 1, limit: .distance(20), stop: .distance(20, risk: .exposed))
            .expectsOne(timeout: 2, on: self)
        self.wait(for: [queue.sync {
                let exp = self.expectation(description: "Position creation.")
                waiter = Waiter(reference: referenceOpened, expectation: exp)
                return exp
            }], timeout: 2)
        
        // 3. Retrieve the position.
        let positionId = api.deals
            .getConfirmation(reference: referenceOpened)
            .expectsOne(timeout: 2, on: self)
            .deal.id
        
        // 4. Update the open position.
        let referenceAmended = api.deals
            .updatePosition(id: positionId, limitLevel: nil, stop: nil)
            .expectsOne(timeout: 2, on: self)
        self.wait(for: [queue.sync {
                let exp = self.expectation(description: "Position amended.")
                waiter = Waiter(reference: referenceAmended, expectation: exp)
                return exp
            }], timeout: 2)
        
        // 5. Close the open position.
        let referenceClosed = api.deals.closePosition(matchedBy: .epic(market.instrument.epic, expiry: .none), direction: .sell, order: .market, strategy: .execute, size: 1).expectsOne(timeout: 2, on: self)
        self.wait(for: [queue.sync {
                let exp = self.expectation(description: "Position deleted.")
                waiter = Waiter(reference: referenceClosed, expectation: exp)
                return exp
            }], timeout: 3)
        
        // 6. Unsubscribe & disconnect.
        cancellable.cancel()
        streamer.session.disconnect().expectsOne(timeout: 2, on: self)
        XCTAssertEqual(streamer.session.status, .disconnected(isRetrying: false))
    }
}

extension StreamerPositionTests {
    /// Helper object holding the deal reference and the test expectation.
    fileprivate final class Waiter {
        /// The targeted deal reference.
        let reference: IG.Deal.Reference
        /// The expectation barring the test to continue forward.
        let expectation: XCTestExpectation
        /// Boolean indicating whether the streamer confirmation has been received.
        var isConfirmationReceived: Bool = false
        /// Boolean indicating whether the streamer update has been received.
        var isUpdateReceived: Bool = false
        
        init(reference: IG.Deal.Reference, expectation: XCTestExpectation) {
            self.reference = reference
            self.expectation = expectation
        }
    }
}
