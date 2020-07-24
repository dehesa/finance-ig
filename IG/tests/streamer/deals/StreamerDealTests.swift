import XCTest
import IG
import ConbiniForTesting
import Combine

final class StreamerDealTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let _acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Tests for the stream deal subscription (with snapshot).
    func testDealsSnapshot() {
        let (rootURL, creds) = self.streamerCredentials(from: self._acc)
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        streamer.session.connect().expectsCompletion(timeout: 2, on: self)
        XCTAssertTrue(streamer.session.status.isReady)
        
        streamer.deals.subscribeToDeals(account: self._acc.id, fields: [.confirmations], snapshot: true)
            .expectsAtLeast(values: 1, timeout: 2, on: self) {
                XCTAssertTrue($0.confirmation != nil || $0.update != nil)
            }
        
        streamer.session.disconnect().expectsOne(timeout: 2, on: self)
        XCTAssertEqual(streamer.session.status, .disconnected(isRetrying: false))
    }
    
    /// Tests for the stream deal subscription (without snapshot).
//    func testEmptyDeals() {
//        let (rootURL, creds) = self.streamerCredentials(from: self._acc)
//        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
//
//        streamer.session.connect().expectsCompletion(timeout: 2, on: self)
//        XCTAssertTrue(streamer.session.status.isReady)
//
//        let cancellable = streamer.deals.subscribeToDeals(account: self._acc.id, fields: [.confirmations], snapshot: false)
//            .sink(receiveCompletion: {
//                guard case .finished = $0 else { return XCTFail() }
//            }, receiveValue: { _ in XCTFail() })
//
//        self.wait(seconds: 2)
//        cancellable.cancel()
//
//        streamer.session.disconnect().expectsOne(timeout: 2, on: self)
//        XCTAssertEqual(streamer.session.status, .disconnected(isRetrying: false))
//    }
}
