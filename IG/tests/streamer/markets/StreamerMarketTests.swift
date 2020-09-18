import XCTest
import IG
import Combine

final class StreamerMarketTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests the market info subscription.
    func testMarketSubscriptions() throws {
        let api = API()
        api.session.login(type: .certificate, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let creds = (api: try XCTUnwrap(api.session.credentials), streamer: try Streamer.Credentials(api.session.credentials))
        let streamer = Streamer(rootURL: creds.api.streamerURL, credentials: creds.streamer)
        
        streamer.session.connect().expectsCompletion(timeout: 2, on: self)
        XCTAssertTrue(streamer.session.status.isReady)

        let epic: IG.Market.Epic = "CS.D.EURGBP.MINI.IP"
        streamer.markets.subscribe(epic: epic, fields: .all)
            .expectsAtLeast(values: 3, timeout: 6, on: self) { (market) in
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
            }
        
        streamer.session.disconnect().expectsOne(timeout: 2, on: self)
        XCTAssertEqual(streamer.session.status, .disconnected(isRetrying: false))
    }
}
