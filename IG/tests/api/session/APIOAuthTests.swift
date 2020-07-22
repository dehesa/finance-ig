@testable import IG
import ConbiniForTesting
import XCTest

/// Tests for the API OAuth endpoints.
final class APIOAuthTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let _acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Test the OAuth lifecycle: session creation, refresh, and disconnection.
    func testOAuth() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: nil, targetQueue: nil)
        // Check the API is set up with the test user
        guard let user = self._acc.api.user else {
            return XCTFail("OAuth tests can't be performed without username and password")
        }
        // Log in through OAuth with the test account
        let credentials = api.session.loginOAuth(key: self._acc.api.key, user: user).expectsOne(timeout: 2, on: self)
        XCTAssertFalse(credentials.client.rawValue.isEmpty)
        XCTAssertEqual(credentials.key, self._acc.api.key)
        XCTAssertEqual(credentials.account, self._acc.id)
        XCTAssertFalse(credentials.token.isExpired)
        guard case .oauth(let access, let refresh, let scope, let type) = credentials.token.value else {
            return XCTFail("Credentials were expected to be OAuth. Credentials received: \(credentials)")
        }
        XCTAssertFalse(access.isEmpty)
        XCTAssertFalse(refresh.isEmpty)
        XCTAssertFalse(scope.isEmpty)
        XCTAssertFalse(type.isEmpty)
        // Generate a typical request header
        let headers = credentials.requestHeaders
        XCTAssertEqual(headers[.authorization], "\(type) \(access)")
        XCTAssertEqual(headers[.account], self._acc.id.rawValue)
        // Check the refresh operation work as intended.
        let token = api.session.refreshOAuth(token: refresh, key: self._acc.api.key).expectsOne(timeout: 2, on: self)
        XCTAssertFalse(token.isExpired)
        guard case .oauth(let newAccess, let newRefresh, let newScope, let newType) = token.value else {
            return XCTFail("The refresh operation didn't return an OAuth token")
        }
        XCTAssertNotEqual(access, newAccess)
        XCTAssertNotEqual(refresh, newRefresh)
        XCTAssertEqual(scope, newScope)
        XCTAssertEqual(type, newType)

        var newCredentials = credentials
        newCredentials.token = token
        api.channel.credentials = newCredentials
        
        api.session.logout().expectsCompletion(timeout: 1, on: self)
        XCTAssertNil(api.channel.credentials)
    }
}
