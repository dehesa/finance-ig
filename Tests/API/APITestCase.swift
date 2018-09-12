@testable import IG
import ReactiveSwift
import XCTest

/// Any test focusing on API calls should inherit from this class.
class APITestCase: XCTestCase {
    /// API instance handling the HTTP calls (whether real or mocked).
    var api: API!
    /// The account where the test will be run over.
    private(set) var account: Account!
    
    override func setUp() {
        super.setUp()
        
        self.account = Account.make()
        self.api = APITestCase.makeAPI(url: self.account.api.url)
    }
    
    override func tearDown() {
        self.api = nil
        self.account = nil
        
        super.tearDown()
    }
}

extension APITestCase {
    /// Designated way of creating an API instance for testing.
    /// - parameter url: URL location of the endpoint servers.
    /// - returns: API instance/session that can be file-based or ULR-based depending on the testing environment variables specified in `account`.
    static func makeAPI(url: URL) -> API {
        switch Account.SupportedScheme(url: url)! {
        case .file:  return API(rootURL: url, session: APIFileSession())
        case .https: return API(rootURL: url, session: URLSession(configuration: API.defaultSessionConfigurations))
        }
    }
    
    /// Convenience property that returns the data within `account` into a Login Request information package.
    static func loginData(account: Account) -> API.Request.Login {
        let api = account.api
        return try! API.Request.Login(apiKey: api.key, accountId: account.accountId, username: api.username, password: api.password)
    }
    
    /// Convenience function starting the signal passed as parameter and expecting it to complete.
    /// - parameter description: The description for the test expectation.
    /// - parameter endpoints: Endpoint/s being tested.
    /// - parameter signingProcess: Whether the log in/out calls will be added to the endpoint test (at the beginning and end).
    /// - parameter timeout: The time to wait before the expectation fail. If a signing process is selected, 1 second is added to the timeout.
    /// - parameter expectationHandler: The handler called in whathever outcome of the expectation.
    func test<V>(_ description: String, _ endpoints: SignalProducer<V,API.Error>, signingProcess: API.Request.Session? = nil, timeout: TimeInterval, expectationHandler: XCWaitCompletionHandler? = nil) {
        let expectation = self.expectation(description: description)
        
        let eventHandler: Signal<Void,API.Error>.Observer.Action = {
            switch $0 {
            case .value(_):      return
            case .completed:     return expectation.fulfill()
            case .interrupted:   XCTFail("Operation was interrupted.")
            case .failed(let e): XCTFail("Operation failed: \(e)")
            }
        }
        
        var wait: TimeInterval = timeout
        let disposable: Disposable
        
        if let signingProcess = signingProcess {
            // If there is a signing process expected, +1.5 seconds are added to the timeout.
            wait += 1.5
            let loginData = APITestCase.loginData(account: self.account)
            disposable = self.api.sessionLogin(loginData, type: signingProcess)
                .flatMap(.latest) { (credentials) -> SignalProducer<V,API.Error> in
                    self.api.updateCredentials(credentials)
                    return endpoints
               }.then(api.sessionLogout())
                .start(eventHandler)
        } else {
            disposable = endpoints.start {
                let ignoreValueEvent = $0.map { (_) in return }
                eventHandler(ignoreValueEvent)
            }
        }
        
        self.waitForExpectations(timeout: wait) { (error) in
            if let _ = error {
                disposable.dispose()
            }
            expectationHandler?(error)
        }
    }
}
