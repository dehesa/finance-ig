@testable import IG
import ReactiveSwift
import XCTest

/// Any test focusing on API calls should inherit from this class.
class APITestCase: XCTestCase {
    /// API instance handling the HTTP calls (whether real or mocked).
    var api: API!
    /// The account where the test will be run over.
    private(set) var account: TestAccount!
    
    override func setUp() {
        super.setUp()
        // Fetch the account JSON file location set on the environment key...
        self.account = TestAccount.make(from: "io.dehesa.money.ig.tests.account")
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
        switch TestAccount.SupportedScheme(url: url)! {
        case .file:  return API(rootURL: url, channel: APIFileSession())
        case .https: return API(rootURL: url, channel: URLSession(configuration: API.defaultSessionConfigurations))
        }
    }
    
    /// Convenience function starting the signal passed as parameter and expecting it to complete.
    /// - parameter description: The description for the test expectation.
    /// - parameter endpoints: Endpoint/s being tested.
    /// - parameter signingProcess: Whether the log in/out calls will be added to the endpoint test (at the beginning and end).
    /// - parameter timeout: The time to wait before the expectation fail. If a signing process is selected, `timeoutAddition` seconds are added to the timeout.
    /// - parameter expectationHandler: The handler called in whathever outcome of the expectation.
    func test<V>(_ description: String, _ endpoints: SignalProducer<V,API.Error>, signingProcess: API.Request.Session.Kind?, timeout: TimeInterval, expectationHandler: XCWaitCompletionHandler? = nil) {
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
        let timeoutAddition: TimeInterval = 1.5
        let disposable: Disposable
        
        if let signingProcess = signingProcess {
            let user = self.account.api.user
            // If signing is requred, then +1.5 seconds are added to the timeout.
            wait += timeoutAddition
            
            disposable = self.api.session.login(type: signingProcess, apiKey: self.account.api.key, user: user)
                .then(endpoints.map { _ in return })
                .then(api.session.logout())
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
