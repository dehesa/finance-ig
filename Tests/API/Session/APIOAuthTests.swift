@testable import IG
import XCTest

/// Tests for the API OAuth endpoints.
final class APIOAuthTests: XCTestCase {
    /// Test the OAuth lifecycle: session creation, refresh, and disconnection.
    func testOAuth() {
        let acc = Test.account(environmentKey: "io.dehesa.money.ig.tests.account")
        let api = Test.makeAPI(rootURL: acc.api.rootURL, credentials: nil, targetQueue: nil)
        
        guard let user = acc.api.user else {
            return XCTFail("OAuth tests can't be performed without username and password")
        }
        
        let credentials = api.session.loginOAuth(key: acc.api.key, user: user)
            .expectsOne { self.wait(for: [$0], timeout: 2) }
        XCTAssertFalse(credentials.client.rawValue.isEmpty)
        XCTAssertEqual(credentials.key, acc.api.key)
        XCTAssertEqual(credentials.account, acc.identifier)
        XCTAssertFalse(credentials.token.isExpired)
        guard case .oauth(let access, let refresh, let scope, let type) = credentials.token.value else {
            return XCTFail("Credentials were expected to be OAuth. Credentials received: \(credentials)")
        }
        XCTAssertFalse(access.isEmpty)
        XCTAssertFalse(refresh.isEmpty)
        XCTAssertFalse(scope.isEmpty)
        XCTAssertFalse(type.isEmpty)
        
        let headers = credentials.requestHeaders
        XCTAssertEqual(headers[.authorization], "\(type) \(access)")
        XCTAssertEqual(headers[.account], acc.identifier.rawValue)

        let token = api.session.refreshOAuth(token: refresh, key: acc.api.key)
            .expectsOne { self.wait(for: [$0], timeout: 2) }
        XCTAssertFalse(token.isExpired)
        guard case .oauth(let newAccess, let newRefresh, let newScope, let newType) = token.value else {
            fatalError()
        }
        XCTAssertNotEqual(access, newAccess)
        XCTAssertNotEqual(refresh, newRefresh)
        XCTAssertEqual(scope, newScope)
        XCTAssertEqual(type, newType)

        var newCredentials = credentials
        newCredentials.token = token
        api.session.credentials = newCredentials
        
        api.session.logout()
            .expectsCompletion { self.wait(for: [$0], timeout: 1) }
        XCTAssertNil(api.session.credentials)
    }
}
