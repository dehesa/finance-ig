import XCTest
import Combine
import IG

final class StreamerSessionTests: XCTestCase {
    /// Tests the connection/disconnection events.
    func testStreamerSession() {
        let (rootURL, creds) = Test.account(environmentKey: "io.dehesa.money.ig.tests.account").streamerCredentials
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        let connectionStatuses = streamer.session.connect().waitForAll()
        XCTAssertNotNil(connectionStatuses.last)
        XCTAssertTrue(connectionStatuses.last!.isReady)
        XCTAssertTrue(streamer.session.status.isReady)
        
        Empty.wait(for: .milliseconds(300))
        
        let disconnectionStatuses = streamer.session.disconnect().waitForAll()
        XCTAssertNotNil(disconnectionStatuses.last)
        XCTAssertEqual(disconnectionStatuses.last!, .disconnected(isRetrying: false))
        XCTAssertEqual(streamer.session.status, .disconnected(isRetrying: false))
    }
    
    func testUnsubscribeFromNone() {
        let (rootURL, creds) = Test.account(environmentKey: "io.dehesa.money.ig.tests.account").streamerCredentials
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        _ = streamer.session.connect().waitForAll()
        XCTAssertTrue(streamer.session.status.isReady)
        
        Empty.wait(for: .milliseconds(300))
        
        let items = streamer.session.unsubscribeAll().waitForAll()
        XCTAssertTrue(items.isEmpty)
        
        _ = streamer.session.disconnect().waitForAll()
        XCTAssertEqual(streamer.session.status, .disconnected(isRetrying: false))
    }
}
