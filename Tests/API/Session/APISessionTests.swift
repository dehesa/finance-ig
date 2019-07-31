import XCTest
import ReactiveSwift
@testable import IG

/// Tests API Session related endpoints.
final class APISessionTests: XCTestCase {
    /// Tests the Session information retrieval mechanisms.
    func testSession() {
        let api = Test.makeAPI(credentials: nil)
        
        let info: (accountId: String, apiKey: String) = (Test.account.identifier, Test.account.api.key)
        guard case .user(let user) = Test.account.api.credentials else { return XCTFail("OAuth tests can't be performed without username and password.") }
        
        try! api.session.login(type: .oauth, apiKey: info.apiKey, user: user).single()!.get()
        let session = try! api.session.get().single()!.get()
        XCTAssertGreaterThan(session.clientId, 0)
        XCTAssertEqual(session.accountId, info.accountId)
        XCTAssertNotNil(session.streamerURL.scheme)
        XCTAssertEqual(session.streamerURL.scheme!, "https")
        try! api.session.logout().single()!.get()
    }
}
