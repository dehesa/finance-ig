import IG
import ReactiveSwift
import XCTest

final class StreamerSessionTests: XCTestCase {
    /// Tests the connection/disconnection events.
    func testStreamerSession() {
        let scheduler = QueueScheduler(suffix: ".streamer.session")
        
        // 0. Create the streamer and check that is disconnected.
        let streamer = Test.makeStreamer(autoconnect: .no)
        XCTAssertEqual(streamer.session.status.value, .disconnected(isRetrying: false))
        
        // 1. Test connection.
        XCTAssertNoThrow(try streamer.session
            .connect()
            .timeout(after: 1.5, on: scheduler) { .invalidRequest(message: "A connection couldn't be established. Statuses:\n\($0.debugDescription)") }
            .wait().get() )
        XCTAssertTrue(streamer.session.status.value.isReady)
        
        // 2. Give 0.5 for a break
        XCTAssertNoThrow(try SignalProducer.empty(after: 0.5, on: scheduler).wait().get())
        
        // 3. Test disconnection.
        XCTAssertNoThrow(
            try streamer.session
            .disconnect()
            .timeout(after: 1.5, on: scheduler) { .invalidRequest(message: "The connection couldn't be closed correctly. Statuses:\n\($0.debugDescription)") }
            .wait().get() )
        XCTAssertEqual(streamer.session.status.value, .disconnected(isRetrying: false))
    }
}
