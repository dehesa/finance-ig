import XCTest
import Combine
@testable import IG

final class StreamerSessionTests: XCTestCase {
    /// Tests the connection/disconnection events.
    func testStreamerSession() {
        let (rootURL, creds) = Test.account(environmentKey: "io.dehesa.money.ig.tests.account").streamerCredentials
        let streamer = Test.makeStreamer(rootURL: rootURL, credentials: creds, targetQueue: nil)
        
        let statuses = streamer.session.connect().waitForAll(timeout: .seconds(4))
        print(statuses)
        
//        // 1. Test connection.
//        self.test( streamer.session.connect(), timeout: 1.5, on: scheduler) {
//            XCTAssertNotNil($0.last)
//            XCTAssertTrue($0.last!.isReady)
//            XCTAssertEqual($0.last!, streamer.session.status.value)
//        }
//        
//        // 2. Give 0.5 for a break
//        XCTAssertNoThrow(try SignalProducer.empty(after: 0.5, on: scheduler).wait().get())
//        
//        // 3. Test disconnection.
//        self.test( streamer.session.disconnect(), timeout: 1.5, on: scheduler) {
//            XCTAssertNotNil($0.last)
//            XCTAssertEqual($0.last!, .disconnected(isRetrying: false))
//            XCTAssertEqual($0.last!, streamer.session.status.value)
//        }
    }
}

//    var streamer: IG.Streamer.Credentials {
//        guard case .success = self.streamerSemaphore.wait(timeout: .now() + self.timeout) else { fatalError() }
//        defer { self.streamerSemaphore.signal() }
//
//        if let credentials = self.streamerCredentials { return credentials }
//
//        if let user = Test.account.streamer?.credentials {
//            self.streamerCredentials = .init(identifier: user.identifier, password: user.password)
//            return self.streamerCredentials!
//        }
//
//        var apiCredentials = self.api
//        if case .certificate = apiCredentials.token.value {
//            self.streamerCredentials = try! .init(credentials: apiCredentials)
//            return self.streamerCredentials!
//        }
//
//        var api: IG.API! = .init(rootURL: Test.account.api.rootURL, credentials: apiCredentials, targetQueue: nil)
//        defer { api = nil }
//
//        switch api.session.refreshCertificate().single() {
//        case .none: fatalError("The certificate credentials couldn't be fetched from the server on the root URL: \(api.rootURL)")
//        case .failure(let error): fatalError("\(error)")
//        case .success(let token):
//            apiCredentials.token = token
//            self.streamerCredentials = try! .init(credentials: apiCredentials)
//            return self.streamerCredentials!
//        }
//    }
//}
