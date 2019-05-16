@testable import IG
import ReactiveSwift
import XCTest

/// Any test focusing on Streamer events should inherit from this class.
class StreamerTestCase: XCTestCase {
    /// Streamer instance handling all Lightstreamer events (whether real or mocked).
    var streamer: Streamer!
    
    override func setUp() {
        super.setUp()
        self.streamer = StreamerTestCase.makeStreamer()
    }
    
    override func tearDown() {
        self.streamer = nil
        super.tearDown()
    }
}

extension StreamerTestCase {
    /// Convenience function starting the signal passed as parameter and expecting it to complete.
    /// - parameter description: The description for the test expectation.
    /// - parameter endpoints: Subscription/s being tested.
    /// - parameter numValues: The number of values to receive before the subscription can be considered successful.
    /// - parameter timeout: The time to wait before the expectation fail.
    /// - parameter expectationHandler: The handler called in whathever outcome of the expectation.
    func test<V>(_ description: String, _ subscriptions: SignalProducer<V,Streamer.Error>, numValues: Int, timeout: TimeInterval, expectationHandler: XCWaitCompletionHandler? = nil) {
        guard numValues > 0 else { return XCTFail("At least one value need to be expected.") }
        
        let valuesExpectation = self.expectation(description: description)
        let disconnectExpectation = self.expectation(description: "Streamer disconnection.")
        
        let statusDisposable = self.streamer.status.signal.observeValues {
            guard case .disconnected(let isRetrying) = $0, !isRetrying else { return }
            disconnectExpectation.fulfill()
        }
        
        var countdown = numValues
        var valuesDisposable: Disposable?
        valuesDisposable = subscriptions.start { [weak self] (event) in
            switch event {
            case .value(_):
                countdown = countdown - 1
                
                guard countdown == 0 else { return }
                // If the countdown reached the end,
                valuesExpectation.fulfill()
                valuesDisposable?.dispose();
                valuesDisposable = nil
            case .completed, .interrupted:
                if (countdown > 0) {
                    XCTFail("Operation failed, since \(numValues) values were expected, but only \(numValues - countdown) values were received.")
                }
                self?.streamer.disconnect()
            case .failed(let e):
                XCTFail("Operation failed: \(e)")
            }
        }
        
        self.streamer.connect()
        
        self.waitForExpectations(timeout: timeout) { (error) in
            if let _ = error {
                valuesDisposable?.dispose()
                statusDisposable?.dispose()
            }
            
            expectationHandler?(error)
            self.streamer = nil
        }
    }
}

extension StreamerTestCase {
    /// Semaphore controling the single request of URL Streamer credentials.
    private static let semaphore = DispatchSemaphore(value: 1)
    /// Streamer credentials used around a "testing wave".
    private static var loginData: LoginData? = nil
    
    /// Creates a streamer given the details in the account.
    /// - parameter account: Account data to be use for the following barrage of tests.
    fileprivate static func makeStreamer(timeout: DispatchTime = .now() + .seconds(5)) -> Streamer {
        // Take the semaphore so only one test at a time can access the loginData.
        guard case .success = self.semaphore.wait(timeout: timeout) else {
            fatalError("Streamer credentials request failed after timeout completed without response.")
        }
        
        let loginData: LoginData = self.loginData ?? {
            self.loginData = self.extractLoginData(from: Account.make())
            return self.loginData!
        }()
        self.semaphore.signal()

        switch loginData {
        case .file(let rootURL):
            let session = StreamerFileSession(serverAddress: rootURL.absoluteString, adapterSet: nil)
            return Streamer(rootURL: rootURL, session: session, autoconnect: false)
        case .https(let rootURL, let credentials):
            return Streamer(rootURL: rootURL, credentials: credentials, autoconnect: false)
        }
    }
    
    /// Temporary enum conveying whether the streamer is supposed to the file-based or url-based.
    private enum LoginData {
        case file(rootURL: URL)
        case https(rootURL: URL, credentials: Streamer.Credentials)
    }
    
    /// Specify the streamer type and returns the streamer login data.
    /// - note: If the streamer is url-based and there are no credentials specified in `account`, this function will block and call the API asynchronously.
    /// - parameter account: Information about the testing environment and testing account.
    private static func extractLoginData(from account: Account) -> StreamerTestCase.LoginData {
        switch (account.streamer.url, account.streamer.username, account.streamer.password) {
        // If `account` points to a file-based streamer, no credentials are needed.
        case (let rootURL?, _, _) where Account.SupportedScheme(url: rootURL)! == .file:
            return .file(rootURL: rootURL)
        // If `account` points to a url-based streamer and there are credentials, return those.
        case (let rootURL?, let username?, let password?) where Account.SupportedScheme(url: rootURL)! == .https:
            let credentials = Streamer.Credentials(identifier: username, password: password)
            return .https(rootURL: rootURL, credentials: credentials)
        // If `account` points to a url-based streamer and there is no credentials, ask the API for some.
        default:
            let apiLoginData = APITestCase.loginData(account: account)
            guard let result = self.requestCredentials(apiURL: account.api.url, apiLoginData: apiLoginData) else {
                fatalError("The Streamer credentials couldn't be retrieved from the API.")
            }
            return result
        }
    }

    /// Synchronously (blocks the thread) request the streamer credentials.
    /// - parameter url: The root URL for the API servers. It can be file based.
    /// - parameter loginData: Credentials needed to request the Lightstreamer credentials.
    /// - parameter timeout: The latest time to wait for an answer from the API.
    private static func requestCredentials(apiURL: URL, apiLoginData: API.Request.Login) -> StreamerTestCase.LoginData? {
        // The API might be file-based (not URL-based) is specified like so in `account`.
        var api: API! = APITestCase.makeAPI(url: apiURL)
        guard let apiResult = api.certificateLogin(apiLoginData).first() else {
            XCTFail("Streamer credentials request was interrupted.")
            return nil
        }
        
        api = nil
        guard let apiCredentials = apiResult.value else {
            XCTFail("Streamer credentials couldn't be requested. The following error was received from the API:\n\(apiResult.error!)")
            return nil
        }
        
        do {
            let streamerURL = apiCredentials.streamerURL
            let streamerCredentials = try apiCredentials.streamer()
            return .https(rootURL: streamerURL, credentials: streamerCredentials)
        } catch let error {
            XCTFail("Certificate credentials were requested to the API, but the response couldn't be parsed into a Streamer credentials format. Underlying error: \(error)")
            return nil
        }
    }
}
