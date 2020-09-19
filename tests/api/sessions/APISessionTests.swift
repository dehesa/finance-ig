#if DEBUG
@testable import IG
import ConbiniForTesting
import XCTest

/// Tests API Session related endpoints.
final class APISessionTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests the Session information retrieval mechanisms.
    func testAPISession() {
        let api = API()
        XCTAssertEqual(api.session.status, .logout)
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        XCTAssertNotNil(api.channel.credentials)
        let credentials = api.channel.credentials!
        
        let session = api.session.get().expectsOne(timeout: 2, on: self)
        let now = Date()
        XCTAssertEqual(session.account, credentials.account)
        XCTAssertEqual(session.client, credentials.client)
        XCTAssertEqual(session.streamerURL, credentials.streamerURL)
        XCTAssertEqual(session.timezone.secondsFromGMT(for: now), credentials.timezone.secondsFromGMT(for: now))
        
        api.session.refresh().expectsCompletion(timeout: 1.2, on: self)
        XCTAssertNotNil(api.channel.credentials)
        XCTAssertGreaterThanOrEqual(api.channel.credentials!.token.expirationDate, credentials.token.expirationDate)
        
        api.session.logout().expectsCompletion(timeout: 1, on: self)
    }
    
    /// Tests the static status events.
    func testAPIStaticStatus() {
        let api = API()
        XCTAssertEqual(api.session.status, .logout)
        
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        guard case .ready(let date) = api.session.status, date > Date() else { return XCTFail("The API configuration status is not properly set") }
        
        api.session.logout().expectsCompletion(timeout: 1, on: self)
        XCTAssertEqual(api.session.status, .logout)
    }
    
    /// Tests the status delivery through subscriptions.
    /// - remark: This test takes around 62 seconds to complete since it checks the OAuth expiration date (which is 60 seconds).
    func testAPIStatusSubscription() {
        let api = API()
        XCTAssertEqual(api.session.status, .logout)
        
        var statuses: [API.Session.Status] = []
        let cancellable = api.session.statusStream.prepend(api.session.status).sink { statuses.append($0) }
        
        api.session.login(type: .oauth, key: "<#API key#>", user: ["<#Username#>", "<#Password#>"]).expectsCompletion(timeout: 1.2, on: self)
        
        guard case .ready(let limit) = api.session.status, limit > Date() else { return XCTFail() }
        self.wait(seconds: limit.timeIntervalSinceNow + 2)
        
        XCTAssertEqual(statuses, [.logout, .ready(till: limit), .expired])
        cancellable.cancel()
    }
}
#endif
