@testable import IG
import ReactiveSwift
import XCTest

/// Tests API Session related endpoints.
final class APISessionTests: XCTestCase {
    /// Tests the Session information retrieval mechanisms.
    func testAPISession() {
        let api = Test.makeAPI(credentials: nil)
        
        let key = Test.account.api.key
        let account = Test.account.identifier
        guard case .user(let user) = Test.account.api.credentials else { return XCTFail("OAuth tests can't be performed without username and password.") }
        
        try! api.session.login(type: .oauth, key: key, user: user).single()!.get()
        let session = try! api.session.get().single()!.get()
        XCTAssertFalse(session.client.rawValue.isEmpty)
        XCTAssertEqual(session.account, account)
        XCTAssertNotNil(session.streamerURL.scheme)
        XCTAssertEqual(session.streamerURL.scheme!, "https")
        try! api.session.logout().single()!.get()
    }
}
