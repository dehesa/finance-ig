@testable import IG
import ConbiniForTesting
import XCTest

/// Tests API Session related endpoints.
final class APISessionTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Tests the Session information retrieval mechanisms.
    func testAPISession() {
        let api = Test.makeAPI(rootURL: self.acc.api.rootURL, credentials: nil, targetQueue: nil)

        guard let user = self.acc.api.user else {
            return XCTFail("Session tests can't be performed without username and password")
        }

        api.session.login(type: .oauth, key: self.acc.api.key, user: user)
            .expectsCompletion(timeout: 1.2, on: self)
        XCTAssertNotNil(api.channel.credentials)
        
        let credentials = api.channel.credentials!
        XCTAssertEqual(self.acc.api.key, credentials.key)
        XCTAssertEqual(self.acc.api.rootURL, api.rootURL)
        
        let session = api.session.get()
            .expectsOne(timeout: 2, on: self)
        let now = Date()
        XCTAssertEqual(session.account, credentials.account)
        XCTAssertEqual(session.client, credentials.client)
        XCTAssertEqual(session.streamerURL, credentials.streamerURL)
        XCTAssertEqual(session.timezone.secondsFromGMT(for: now), credentials.timezone.secondsFromGMT(for: now))
        
        api.session.refresh()
            .expectsCompletion(timeout: 1.2, on: self)
        XCTAssertNotNil(api.channel.credentials)
        XCTAssertGreaterThanOrEqual(api.channel.credentials!.token.expirationDate, credentials.token.expirationDate)
        
        api.session.logout()
            .expectsCompletion(timeout: 1, on: self)
    }
}
