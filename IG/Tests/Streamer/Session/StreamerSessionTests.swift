import XCTest
import IG
import ConbiniForTesting
import Combine

final class StreamerSessionTests: XCTestCase {
    /// Tests the connection/disconnection events.
    func testStreamerSession() {
        let (rootURL, creds) = self.streamerCredentials(from: Test.account(environmentKey: Test.defaultEnvironmentKey))
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        let connectionStatus = streamer.session.connect().expectsOne(timeout: 2, on: self)
        XCTAssertTrue(connectionStatus.isReady)
        XCTAssertEqual(connectionStatus, streamer.session.status)
        
        self.wait(seconds: 0.3)
        
        let disconnectionStatus = streamer.session.disconnect().expectsOne(timeout: 1, on: self)
        XCTAssertEqual(disconnectionStatus, .disconnected(isRetrying: false))
        XCTAssertEqual(disconnectionStatus, streamer.session.status)
    }
    
    /// Test unsubscription when there is no subscriptions.
    func testUnsubscribeFromNone() {
        let (rootURL, creds) = self.streamerCredentials(from: Test.account(environmentKey: Test.defaultEnvironmentKey))
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect().expectsOne(timeout: 2, on: self)
        XCTAssertTrue(streamer.session.status.isReady)
        
        self.wait(seconds: 0.3)
        
        streamer.session.unsubscribeAll()
        streamer.session.disconnect().expectsOne(timeout: 1, on: self)
        XCTAssertEqual(streamer.session.status, .disconnected(isRetrying: false))
    }
}
