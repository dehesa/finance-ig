@testable import IG
import XCTest

/// Tests API Session related endpoints.
final class APISessionTests: XCTestCase {
    /// Tests the Session information retrieval mechanisms.
    func testAPISession() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: nil, targetQueue: nil)

        guard let user = acc.api.user else {
            return XCTFail("Session tests can't be performed without username and password")
        }

        api.session.login(type: .oauth, key: acc.api.key, user: user)
            .expectsCompletion { self.wait(for: [$0], timeout: 1.2) }
        XCTAssertNotNil(api.session.credentials)
        
        let credentials = api.session.credentials!
        XCTAssertEqual(acc.api.key, credentials.key)
        XCTAssertEqual(acc.api.rootURL, api.rootURL)
        
        let session = api.session.get()
            .expectsSuccess { self.wait(for: [$0], timeout: 2) }
        XCTAssertEqual(session.account, credentials.account)
        XCTAssertEqual(session.client, credentials.client)
        XCTAssertEqual(session.streamerURL, credentials.streamerURL)
        XCTAssertEqual(session.timezone, credentials.timezone)
        
        api.session.refresh()
            .expectsCompletion { self.wait(for: [$0], timeout: 1.2) }
        XCTAssertNotNil(api.session.credentials)
        XCTAssertGreaterThanOrEqual(api.session.credentials!.token.expirationDate, credentials.token.expirationDate)
        
        api.session.logout()
            .expectsCompletion { self.wait(for: [$0], timeout: 1) }
    }
}
