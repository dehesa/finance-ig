import XCTest
import Lightstreamer_macOS_Client
import IG

final class StreamerPlaygroundTests: XCTestCase {
    private let client = LSLightstreamerClient(serverAddress: "https://demo-apd.marketdatasystems.com", adapterSet: nil)
    private let credentials: (user: String, password: String) = {
        let user = ""
        let cst = ""
        let security = ""
        return (user, "CST-\(cst)|XST-\(security)")
    }()
//    private let epic = "CS.D.EURUSD.MINI.IP"
//    private let fields: [Streamer.Request.Market] = Streamer.Request.Market.allCases
        // Streamer.Request.Market.allCases.map { $0.rawValue }
        // ["MARKET_STATE", "UPDATE_TIME", "OFFER", "BID", "MARKET_DELAY", "LOW", "MID_OPEN", "HIGH"]

    override func setUp() {
        print("""
            
            Streamer credentials {
                Identifier: \(self.credentials.user)
                Password:   \(self.credentials.password)
            }
            
            """)
        self.client.connectionDetails.user = credentials.user
        self.client.connectionDetails.setPassword(credentials.password)
        self.client.addDelegate(self)
    }

    override func tearDown() {
        self.client.disconnect()
    }

    fileprivate var subscriptionExpectation: XCTestExpectation!
    
    func testExample() {
//        let subscription = LSSubscription(subscriptionMode: "MERGE", item: "MARKET:\(self.epic)", fields: self.fields.map { $0.rawValue })
//        subscription.addDelegate(self)
//
//        self.client.subscribe(subscription)
        self.client.connect()
//
        self.subscriptionExpectation = self.expectation(description: "Subscription delay.")
//        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(4)) {
//            self.client.unsubscribe(subscription)
//        }
        
        self.waitForExpectations(timeout: 6)
    }
}

extension StreamerPlaygroundTests: LSClientDelegate {
    func client(_ client: LSLightstreamerClient, didChangeStatus status: String) {
        print("[Client] didChangeStatus to: \"\(status)\"")
    }
    
    func client(_ client: LSLightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String?) {
        print("[Client] didReceiveServerError code: \(errorCode), message: \"\(errorMessage ?? "")\"")
    }
}

extension StreamerPlaygroundTests: LSSubscriptionDelegate {
    func subscriptionDidSubscribe(_ subscription: LSSubscription) {
        print("[Subscription] didSubscribe")
    }
    
    func subscriptionDidUnsubscribe(_ subscription: LSSubscription) {
        print("[Subscription] didUnsubscribe")
//        subscriptionExpectation.fulfill()
    }
    
    func subscription(_ subscription: LSSubscription, didUpdateItem itemUpdate: LSItemUpdate) {
        print("[Subscription] \"\(itemUpdate.itemName!.dropFirst(7))\"")
        for (key, value) in itemUpdate.fields as! [String:String] {
            print("\t\(key): \(value)")
        }
    }
    
    func subscription(_ subscription: LSSubscription, didFailWithErrorCode code: Int, message: String?) {
        print("[Subscription] didFail code: \(code), message: \(message ?? "")")
    }
    
    func subscription(_ subscription: LSSubscription, didLoseUpdates lostUpdates: UInt, forItemName itemName: String?, itemPos: UInt) {
        print("[Subscription] didLoseUpdates count: \(lostUpdates), item: \(itemName ?? ""), position: \(itemPos)")
    }
}
