@testable import IG
import ReactiveSwift
import XCTest

extension Test {
    static func makeStreamer(autoconnect: Bool) -> IG.Streamer {
        let rootURL = Self.account.streamer?.rootURL ?? Self.credentials.api.streamerURL
        let credentials = Self.credentials.streamer
        return Self.makeStreamer(rootURL: rootURL, credentials: credentials, autoconnect: autoconnect)
    }
    
    /// Creates a streamer instance from the running test account.
    static func makeStreamer(rootURL: URL, credentials: IG.Streamer.Credentials, autoconnect: Bool) -> IG.Streamer {
        let streamer: IG.Streamer
        
        switch Self.Account.SupportedScheme(url: rootURL) {
        case .none: fatalError("The root URL is invalid. No scheme could be found.\n\(rootURL)")
        case .https:
            streamer = .init(rootURL: rootURL, credentials: credentials, autoconnect: false)
        case .file:
            let existencial = Lifetime.make()
            let channel = StreamerFileChannel(rootURL: rootURL, credentials: credentials, lifetime: existencial.lifetime)
            streamer = .init(rootURL: rootURL, existencial: existencial, channel: channel, autoconnect: false)
        }
        
        if (autoconnect) {
            do {
                try Self.connect(streamer: streamer)
            } catch let error as CustomDebugStringConvertible {
                fatalError(error.debugDescription)
            } catch let error {
                fatalError("\(error)")
            }
        }
        return streamer
    }
    
    /// Synchronously attempt to connect to given streamer.
    ///
    /// If after a given time (in seconds), the streamer didn't manage to connect, throw an error.
    /// - parameter streamer: The framework's streamer.
    /// - parameter timeout: Waiting time for a succesful connection.
    /// - throws: `IG.Streamer.Error`
    private static func connect(streamer: IG.Streamer, scheduler: QueueScheduler = .init(), timeout: TimeInterval = 1.5) throws {
        guard case .disconnected(isRetrying: false) = streamer.session.status.value else {
            throw IG.Streamer.Error.invalidRequest(message: "A connection couldn't be established./nStatuses: \([streamer.session.status.value])")
        }
        
        var statuses: [IG.Streamer.Session.Status] = []
        try streamer.session.connect()
            .on(value: { statuses.append($0) })
            .timeout(after: timeout, on: scheduler) { .invalidRequest(message: "A connection couldn't be established./nStatuses: \([streamer.session.status.value])") }
            .producer.wait().get()
    }
}

//extension StreamerTestCase {
//    /// Convenience function starting the signal passed as parameter and expecting it to complete.
//    /// - parameter description: The description for the test expectation.
//    /// - parameter endpoints: Subscription/s being tested.
//    /// - parameter numValues: The number of values to receive before the subscription can be considered successful.
//    /// - parameter timeout: The time to wait before the expectation fail.
//    /// - parameter expectationHandler: The handler called in whathever outcome of the expectation.
//    func test<V>(_ description: String, _ subscriptions: SignalProducer<V,Streamer.Error>, numValues: Int, timeout: TimeInterval, expectationHandler: XCWaitCompletionHandler? = nil) {
//        guard numValues > 0 else { return XCTFail("At least one value need to be expected.") }
//
//        let valuesExpectation = self.expectation(description: description)
//        let disconnectExpectation = self.expectation(description: "Streamer disconnection.")
//
//        let statusDisposable = self.streamer.status.signal.observeValues {
//            guard case .disconnected(let isRetrying) = $0, !isRetrying else { return }
//            disconnectExpectation.fulfill()
//        }
//
//        var countdown = numValues
//        var valuesDisposable: Disposable?
//        valuesDisposable = subscriptions.start { [weak self] (event) in
//            switch event {
//            case .value(_):
//                countdown = countdown - 1
//
//                guard countdown == 0 else { return }
//                // If the countdown reached the end,
//                valuesExpectation.fulfill()
//                valuesDisposable?.dispose();
//                valuesDisposable = nil
//            case .completed, .interrupted:
//                if (countdown > 0) {
//                    XCTFail("Operation failed, since \(numValues) values were expected, but only \(numValues - countdown) values were received.")
//                }
//                self?.streamer.disconnect()
//            case .failed(let e):
//                XCTFail("Operation failed: \(e)")
//            }
//        }
//
//        self.streamer.connect()
//
//        self.waitForExpectations(timeout: timeout) { (error) in
//            if let _ = error {
//                valuesDisposable?.dispose()
//                statusDisposable?.dispose()
//            }
//
//            expectationHandler?(error)
//            self.streamer = nil
//        }
//    }
//}
