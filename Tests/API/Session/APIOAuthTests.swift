import XCTest
import ReactiveSwift
@testable import IG

/// Tests for the API OAuth endpoints.
final class APIOAuthTests: APITestCase {
    /// Test the OAuth lifecycle: session creation, refresh, and disconnection.
    func testOAuth() {
        // The info needed to request OAuth credentials.
        let info: (accountId: String, apiKey: String, username: String, password: String) = (self.account.accountId, self.account.api.key, self.account.api.username, self.account.api.password)
        
        let endpoints = self.api.session.loginOAuth(apiKey: info.apiKey, user: (info.username, info.password)).on(value: {
            XCTAssertGreaterThan($0.clientId, 0)
            XCTAssertEqual($0.apiKey, info.apiKey)
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
            XCTAssertEqual(headers[.authorization], "\(type) \(access)")
            XCTAssertEqual(headers[.account], info.accountId)
        }).call(on: self.api) { (api, credentials) -> SignalProducer<(API.Credentials,API.Credentials.Token),API.Error> in
            guard case .oauth(_,let refresh,_,_) = credentials.token.value else {
                XCTFail("The refresh token couldn't be acccessed.")
                return .init(error: .invalidCredentials(credentials, message: "The refresh token couldn't be accessed."))
            }

            return api.session.refreshOAuth(token: refresh, apiKey: info.apiKey).map { (credentials, $0) }
        }.on(value: { (oldCredentials, newToken) in
            XCTAssertGreaterThan(newToken.expirationDate, Date())

            guard case .oauth(let oldAccess, let oldRefresh, let oldScope, let oldType) = oldCredentials.token.value else {
                fatalError()
            }
            
            guard case .oauth(let newAccess, let newRefresh, let newScope, let newType) = newToken.value else {
                return XCTFail("Token was expected to be OAuth. Token received after OAuth refresh: \(newToken)")
            }
            
            XCTAssertNotEqual(oldAccess, newAccess)
            XCTAssertNotEqual(oldRefresh, newRefresh)
            XCTAssertEqual(oldScope, newScope)
            XCTAssertEqual(oldType, newType)

            var newCredentials = oldCredentials
            newCredentials.token = newToken
            
            let headers = newCredentials.requestHeaders
            XCTAssertEqual(headers[.authorization], "\(newType) \(newAccess)")
            XCTAssertEqual(headers[.account], info.accountId)
        }).call(on: self.api) { (api, _) in
            return api.session.logout()
        }.on(value: {
            XCTAssertNil(self.api.session.credentials)
        })
        
        self.test("OAuth Login Procedure", endpoints, signingProcess: nil, timeout: 2)
    }
}
