@testable import IG
import ConbiniForTesting
import XCTest

/// Tests API Session related endpoints.
final class APISessionTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let _acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Tests the Session information retrieval mechanisms.
    func testAPISession() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: nil, targetQueue: nil)

        guard let user = self._acc.api.user else {
            return XCTFail("Session tests can't be performed without username and password")
        }

        api.session.login(type: .oauth, key: self._acc.api.key, user: user).expectsCompletion(timeout: 1.2, on: self)
        XCTAssertNotNil(api.channel.credentials)
        
        let credentials = api.channel.credentials!
        XCTAssertEqual(self._acc.api.key, credentials.key)
        XCTAssertEqual(self._acc.api.rootURL, api.rootURL)
        
        let session = api.session.get().expectsOne(timeout: 2, on: self)
        let now = Date()
        XCTAssertEqual(session.account, credentials.account)
        XCTAssertEqual(session.client, credentials.client)
        XCTAssertEqual(session.streamerURL, credentials.streamerURL)
        XCTAssertEqual(session.timezone.secondsFromGMT(for: now), credentials.timezone.secondsFromGMT(for: now))
        
        api.session.refresh().expectsCompletion(timeout: 1.2, on: self)
        XCTAssertNotNil(api.channel.credentials)
        XCTAssertGreaterThanOrEqual(api.channel.credentials!.token.expirationDate, credentials.token.expirationDate)
        
        api.session.logout().expectsCompletion(timeout: 1, on: self)
    }
    
    /// Tests the static status events.
    func testAPIStaticStatus() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: nil, targetQueue: nil)
        guard let user = self._acc.api.user else { return XCTFail("Session tests can't be performed without username and password") }
        
        XCTAssertEqual(api.session.status, .logout)
        api.session.login(type: .oauth, key: self._acc.api.key, user: user)
            .expectsCompletion(timeout: 1.2, on: self)
        
        guard case .ready(let date) = api.session.status,
              date > Date() else { return XCTFail("The API configuration status is not properly set") }
        
        api.session.logout()
            .expectsCompletion(timeout: 1, on: self)
        XCTAssertEqual(api.session.status, .logout)
    }
    
    /// Tests the status delivery through subscriptions.
    /// - remark: This test takes around 62 seconds to complete since it checks the OAuth expiration date (which is 60 seconds).
    func testAPIStatusSubscription() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: nil, targetQueue: nil)
        guard let user = self._acc.api.user else { return XCTFail("Session tests can't be performed without username and password") }
        
        var statuses: [API.Session.Status] = [api.session.status]
        let cancellable = api.session.statusStream.sink { statuses.append($0) }
        
        api.session.login(type: .oauth, key: self._acc.api.key, user: user).expectsCompletion(timeout: 3, on: self)
        
        guard case .ready(let limit) = api.session.status, limit > Date() else { return XCTFail() }
        self.wait(seconds: limit.timeIntervalSinceNow + 2)
        
        XCTAssertEqual(statuses, [.logout, .ready(till: limit), .expired])
        cancellable.cancel()
    }
}