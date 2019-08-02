import IG
import ReactiveSwift
import XCTest

final class StreamerSessionTests: XCTestCase {
    /// Tests the connection/disconnection events.
    func testStreamerSession() {
        //let streamer = Test.makeStreamer(rootURL: URL(string: "file://Streamer")!, credentials: Test.credentials.streamer, autoconnect: false)
        let streamer = Test.makeStreamer(autoconnect: false)
        XCTAssertEqual(streamer.session.status.value, .disconnected(isRetrying: false))
        let scheduler = QueueScheduler(qos: .default, name: Bundle.init(for: Self.self).bundleIdentifier! + ".streamer.session", targeting: nil)
        
        // 1. Test connection.
        var statuses: [IG.Streamer.Session.Status] = []
        XCTAssertNoThrow(try streamer.session.connect()
            .on(value: { statuses.append($0) })
            .timeout(after: 1.5, on: scheduler) { .invalidRequest(message: "A connection couldn't be established./nStatuses: \([streamer.session.status.value])") }
            .producer.wait().get() )
        XCTAssertTrue(streamer.session.status.value.isReady)
        
        // 2. Wait synchronously for 0.2 seconds
        XCTAssertNoThrow(try SignalProducer<Void,Never> { (generator, lifetime) in
            let date = scheduler.currentDate.addingTimeInterval(0.2)
            lifetime += scheduler.schedule(after: date) { generator.sendCompleted() }
        }.wait().get())
        
        // 3. Test disconnection.
        statuses.removeAll()
        XCTAssertNoThrow(try streamer.session.disconnect()
            .on(value: { statuses.append($0) })
            .timeout(after: 1.5, on: scheduler) { .invalidRequest(message: "The connection couldn't be closed correctly./nStatuses: \([streamer.session.status.value])") }
            .producer.wait().get() )
        XCTAssertEqual(streamer.session.status.value, .disconnected(isRetrying: false))
    }
}
