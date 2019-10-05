import XCTest
import IG
import Combine

final class StreamerSessionTests: XCTestCase {
    /// Tests the connection/disconnection events.
    func testStreamerSession() {
        let (rootURL, creds) = self.streamerCredentials(from: Test.account(environmentKey: "io.dehesa.money.ig.tests.account"))
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        let connectionStatuses = streamer.session.connect()
            .expectsAll { self.wait(for: [$0], timeout: 2) }
        XCTAssertNotNil(connectionStatuses.last)
        XCTAssertTrue(connectionStatuses.last!.isReady)
        XCTAssertTrue(streamer.status.isReady)
        
        self.wait(for: 0.3)
        
        let disconnectionStatuses = streamer.session.disconnect()
            .expectsAll { self.wait(for: [$0], timeout: 2) }
        XCTAssertNotNil(disconnectionStatuses.last)
        XCTAssertEqual(disconnectionStatuses.last!, .disconnected(isRetrying: false))
        XCTAssertEqual(streamer.status, .disconnected(isRetrying: false))
    }
    
    func testUnsubscribeFromNone() {
        let (rootURL, creds) = self.streamerCredentials(from: Test.account(environmentKey: "io.dehesa.money.ig.tests.account"))
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect()
            .expectsAll { self.wait(for: [$0], timeout: 2) }
        XCTAssertTrue(streamer.status.isReady)
        
        self.wait(for: 0.3)
        
        let items = streamer.session.unsubscribeAll()
            .expectsAll { self.wait(for: [$0], timeout: 2) }
        XCTAssertTrue(items.isEmpty)
        
        streamer.session.disconnect()
            .expectsAll { self.wait(for: [$0], timeout: 2) }
        XCTAssertEqual(streamer.status, .disconnected(isRetrying: false))
    }
}
