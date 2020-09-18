import XCTest
import IG
import ConbiniForTesting
import Combine

final class StreamerSessionTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests the connection/disconnection events.
    func testStreamerSession() throws {
        let api = API()
        api.session.login(type: .certificate, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let creds = (api: try XCTUnwrap(api.session.credentials), streamer: try Streamer.Credentials(api.session.credentials))
        let streamer = Streamer(rootURL: creds.api.streamerURL, credentials: creds.streamer)
        
        let connectionStatus = streamer.session.connect().expectsOne(timeout: 4, on: self)
        XCTAssertTrue(connectionStatus.isReady)
        XCTAssertEqual(connectionStatus, streamer.session.status)
        
        self.wait(seconds: 0.3)
        
        let disconnectionStatus = streamer.session.disconnect().expectsOne(timeout: 1, on: self)
        XCTAssertEqual(disconnectionStatus, .disconnected(isRetrying: false))
        XCTAssertEqual(disconnectionStatus, streamer.session.status)
    }
    
    /// Test unsubscription when there is no subscriptions.
    func testUnsubscribeFromNone() throws {
        let api = API()
        api.session.login(type: .certificate, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let creds = (api: try XCTUnwrap(api.session.credentials), streamer: try Streamer.Credentials(api.session.credentials))
        let streamer = Streamer(rootURL: creds.api.streamerURL, credentials: creds.streamer)
        
        streamer.session.connect().expectsOne(timeout: 2, on: self)
        XCTAssertTrue(streamer.session.status.isReady)
        
        self.wait(seconds: 0.3)
        
        streamer.session.unsubscribeAll()
        streamer.session.disconnect().expectsOne(timeout: 1, on: self)
        XCTAssertEqual(streamer.session.status, .disconnected(isRetrying: false))
    }
    
    /// Tests the status delivery through subscription.
    func testStreamerStatusSubscription() throws {
        let api = API()
        api.session.login(type: .certificate, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        let creds = (api: try XCTUnwrap(api.session.credentials), streamer: try Streamer.Credentials(api.session.credentials))
        let streamer = Streamer(rootURL: creds.api.streamerURL, credentials: creds.streamer)
        
        var statuses: [Streamer.Session.Status] = [streamer.session.status]
        let cancellable = streamer.session.statusStream.sink { statuses.append($0) }
        
        streamer.session.connect().expectsOne(timeout: 4, on: self)
        XCTAssertTrue(streamer.session.status.isReady)
        
        self.wait(seconds: 0.3)
        
        streamer.session.disconnect().expectsOne(timeout: 2, on: self)
        XCTAssertEqual(streamer.session.status, .disconnected(isRetrying: false))
        
        XCTAssertGreaterThanOrEqual(statuses.count, 4)
        cancellable.cancel()
    }
}
