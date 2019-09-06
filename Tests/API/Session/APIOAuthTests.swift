@testable import IG
import ReactiveSwift
import XCTest

/// Tests for the API OAuth endpoints.
final class APIOAuthTests: XCTestCase {
    /// Test the OAuth lifecycle: session creation, refresh, and disconnection.
    func testOAuth() {
        let api = Test.makeAPI(rootURL: Test.account.api.rootURL, credentials: nil, targetQueue: nil)
        let account = Test.account.identifier
        let key = Test.account.api.key
        guard case .user(let user) = Test.account.api.credentials else {
            return XCTFail("OAuth tests can't be performed without username and password.")
        }
        
        let credentials = try! api.session.loginOAuth(key: key, user: user).single()!.get()
        XCTAssertFalse(credentials.client.rawValue.isEmpty)
        XCTAssertEqual(credentials.key, key)
        XCTAssertEqual(credentials.account, account)
        XCTAssertGreaterThan(credentials.token.expirationDate, Date())
        guard case .oauth(let access, let refresh, let scope, let type) = credentials.token.value else {
            return XCTFail("Credentials were expected to be OAuth. Credentials received: \(credentials)")
        }
        XCTAssertFalse(access.isEmpty)
        XCTAssertFalse(refresh.isEmpty)
        XCTAssertFalse(scope.isEmpty)
        XCTAssertFalse(type.isEmpty)
        let headers = credentials.requestHeaders
        XCTAssertEqual(headers[.authorization], "\(type) \(access)")
        XCTAssertEqual(headers[.account], account.rawValue)

        let token = try! api.session.refreshOAuth(token: refresh, key: key).single()!.get()
        XCTAssertGreaterThan(token.expirationDate, Date())
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
        
        try! api.session.logout().single()!.get()
        XCTAssertNil(api.session.credentials)
    }
}
