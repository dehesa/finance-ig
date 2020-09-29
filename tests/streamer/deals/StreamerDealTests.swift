import IG
import Combine
import Conbini
import XCTest

final class StreamerDealTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests for the stream deal subscription (with snapshot).
    func testDealsSnapshot() throws {
        let api = API()
        api.session.login(type: .certificate, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let creds = (api: try XCTUnwrap(api.session.credentials), streamer: try Streamer.Credentials(api.session.credentials))
        let streamer = Streamer(rootURL: creds.api.streamerURL, credentials: creds.streamer)
        
        streamer.session.connect().expectsCompletion(timeout: 2, on: self)
        XCTAssertTrue(streamer.session.status.isReady)
        
        streamer.deals.subscribe(account: creds.api.account, fields: [.confirmations], snapshot: true)
            .expectsAtLeast(values: 1, timeout: 2, on: self) {
                XCTAssertTrue($0.confirmation != nil || $0.update != nil)
            }
        
        streamer.session.disconnect().expectsOne(timeout: 2, on: self)
        XCTAssertEqual(streamer.session.status, .disconnected(isRetrying: false))
    }
}
