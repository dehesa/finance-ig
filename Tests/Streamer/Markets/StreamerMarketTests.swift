import XCTest
import Combine
@testable import IG

final class StreamerMarketTests: XCTestCase {
    /// Tests the market info subscription.
    func testMarketSubscriptions() {
        let (rootURL, creds) = Test.account(environmentKey: "io.dehesa.money.ig.tests.account").streamerCredentials
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        _ = streamer.session.connect().waitForAll()
        XCTAssertTrue(streamer.session.status.isReady)

        let epic: IG.Market.Epic = "CS.D.EURGBP.MINI.IP"
        let expectation = self.expectation(description: "Testing market: \(epic)")
        
        var values = 0
        #warning("Tests: Build functionality to waitForN()")
        let cancellable = streamer.markets.subscribe(to: epic, fields: .all).sink(receiveCompletion: {
            guard case .failure(let error) = $0 else { return }
            XCTFail(error.debugDescription)
        }, receiveValue: { (market) in
            values += 1
            print(values)
            XCTAssertEqual(market.epic, epic)
            XCTAssertNotNil(market.status)
            XCTAssertNotNil(market.date)
            XCTAssertNotNil(market.isDelayed)
            XCTAssertNotNil(market.bid)
            XCTAssertNotNil(market.ask)
            XCTAssertNotNil(market.day.lowest)
            XCTAssertNotNil(market.day.mid)
            XCTAssertNotNil(market.day.highest)
            XCTAssertNotNil(market.day.changeNet)
            XCTAssertNotNil(market.day.changePercentage)
            
            if values == 2 { expectation.fulfill() }
        })
        
        self.wait(for: [expectation], timeout: 6)
        
        let items = streamer.session.unsubscribeAll().waitForAll(timeout: .seconds(10))
        XCTAssertEqual(items.count, 1)
        
        _ = streamer.session.disconnect().waitForAll()
        XCTAssertEqual(streamer.session.status, .disconnected(isRetrying: false))
    }
}
