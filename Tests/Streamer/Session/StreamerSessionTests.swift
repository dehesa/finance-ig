import XCTest
import ReactiveSwift
@testable import IG

final class StreamerSessionTests: XCTestCase {
    /// Tests the connection/disconnection events.
    func testStreamerSession() {
        let scheduler = QueueScheduler(suffix: ".streamer.session")
        
        // 0. Create the streamer and check that is disconnected.
        let streamer = Test.makeStreamer(autoconnect: .no)
        XCTAssertEqual(streamer.session.status.value, .disconnected(isRetrying: false))
        
        // 1. Test connection.
        self.test( streamer.session.connect(), timeout: 1.5, on: scheduler) {
            XCTAssertNotNil($0.last)
            XCTAssertTrue($0.last!.isReady)
            XCTAssertEqual($0.last!, streamer.session.status.value)
        }
        
        // 2. Give 0.5 for a break
        XCTAssertNoThrow(try SignalProducer.empty(after: 0.5, on: scheduler).wait().get())
        
        // 3. Test disconnection.
        self.test( streamer.session.disconnect(), timeout: 1.5, on: scheduler) {
            XCTAssertNotNil($0.last)
            XCTAssertEqual($0.last!, .disconnected(isRetrying: false))
            XCTAssertEqual($0.last!, streamer.session.status.value)
        }
    }
}
