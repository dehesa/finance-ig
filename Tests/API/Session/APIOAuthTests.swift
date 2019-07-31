import XCTest
import ReactiveSwift
@testable import IG

/// Tests for the API OAuth endpoints.
final class APIOAuthTests: XCTestCase {
    /// Test the OAuth lifecycle: session creation, refresh, and disconnection.
    func testOAuth() {
        let api = Test.makeAPI(credentials: nil)
        
        // The info needed to request OAuth credentials.
        let info: (accountId: String, apiKey: String) = (Test.account.identifier, Test.account.api.key)
        guard case .user(let user) = Test.account.api.credentials else { return XCTFail("OAuth tests can't be performed without username and password.") }
        
        let credentials = try! api.session.loginOAuth(apiKey: info.apiKey, user: user).single()!.get()
        XCTAssertGreaterThan(credentials.clientId, 0)
        XCTAssertEqual(credentials.apiKey, info.apiKey)
        XCTAssertEqual(credentials.accountId, info.accountId)
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
        XCTAssertEqual(headers[.account], info.accountId)

        let token = try! api.session.refreshOAuth(token: refresh, apiKey: info.apiKey).single()!.get()
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
