import XCTest
import ReactiveSwift
@testable import IG

/// Tests for the API OAuth endpoints.
final class APIOAuthTests: APITestCase {
    /// Test the OAuth lifecycle: session creation, refresh, and disconnection.
    func testOAuth() {
        // The info needed to request OAuth credentials.
        let info = APITestCase.loginData(account: self.account)
        // Login token used to check the correct usage of OAuth refresh tokens.
        var loginToken: API.Credentials.Token! = nil

        let endpoints = self.api.oauthLogin(info).on(value: {
            XCTAssertGreaterThan($0.apiKey.count, 0)
            XCTAssertGreaterThan($0.clientId, 0)
            XCTAssertEqual($0.accountId, info.accountId)
            XCTAssertGreaterThan($0.token.expirationDate, Date())
            
            guard case .oauth(let access, let refresh, let scope, let type) = $0.token.value else {
                return XCTFail("Credentials were expected to be OAuth. Credentials received: \($0)")
            }
            
            XCTAssertFalse(access.isEmpty)
            XCTAssertFalse(refresh.isEmpty)
            XCTAssertFalse(scope.isEmpty)
            XCTAssertFalse(type.isEmpty)
            
            let headers = $0.requestHeaders
            XCTAssertNotNil(headers[.authorization])
            XCTAssertNotNil(headers[.account])
            
            loginToken = $0.token
        }).call(on: self.api) { (api, credentials) -> SignalProducer<API.Credentials,API.Error> in
            api.updateCredentials(credentials)
            return api.oauthRefresh(current: credentials)
        }.on(value: {
            XCTAssertGreaterThan($0.apiKey.count, 0)
            XCTAssertGreaterThan($0.clientId, 0)
            XCTAssertEqual($0.accountId, info.accountId)
            XCTAssertGreaterThan($0.token.expirationDate, Date())
            
            guard case .oauth(let access, let refresh, let scope, let type) = $0.token.value else {
                return XCTFail("Credentials were expected to be OAuth. Credentials received: \($0)")
            }
            
            XCTAssertFalse(access.isEmpty)
            XCTAssertFalse(refresh.isEmpty)
            XCTAssertFalse(scope.isEmpty)
            XCTAssertFalse(type.isEmpty)
            
            let headers = $0.requestHeaders
            XCTAssertNotNil(headers[.authorization])
            XCTAssertNotNil(headers[.account])
            
            // Compare that the login and refresh credentials are not the same.
            //XCTAssertTrue(loginCredentials.token.expiration != creds.token.expiration)
            guard case .oauth(let loginAccess, let loginRefresh, let loginScope, let loginType) = loginToken.value else { return XCTFail() }
            XCTAssertFalse(loginAccess == access)
            XCTAssertFalse(loginRefresh == refresh)
            XCTAssertTrue(loginScope == scope)
            XCTAssertTrue(loginType == type)
        }).call(on: self.api) { (api, credentials) in
            api.updateCredentials(credentials)
            return api.sessionLogout()
        }.on(value: {
            XCTAssertNil(try? self.api.credentials())
        })
        
        self.test("OAuth Login Procedure", endpoints, timeout: 3)
    }
}
