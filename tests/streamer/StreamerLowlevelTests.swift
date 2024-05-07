#if os(macOS) && arch(x86_64)
import Lightstreamer_macOS_Client
#elseif os(macOS)

#elseif os(iOS)
import Lightstreamer_iOS_Client
#elseif os(tvOS)
import Lightstreamer_tvOS_Client
#else
#error("OS currently not supported")
#endif
import Conbini
import XCTest

#if (os(macOS) && arch(x86_64)) || os(iOS) || os(tvOS)

final class StreamerLowlevelTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Tests the Lightstreamer library name and version retrieval.
    func testDynamicLibrary() {
        XCTAssertFalse(LSLightstreamerClient.lib_NAME.isEmpty)
        XCTAssertFalse(LSLightstreamerClient.lib_VERSION.isEmpty)
    }
    
    /// Tests the subscription to the market using the Lightstreamer framework directly.
    func testLowlevelMarketSubscription() {
        // The server address is returned by the API session login.
        let client = LSLightstreamerClient(serverAddress: "<#Lightstreamer server address#>", adapterSet: nil)
        // 1. Connect the Lighstreamer client (the user is the account identifier and the password is a combination of the CST and security header).
        client.connectionDetails.user = "<#Lighstreamer user#>"
        client.connectionDetails.setPassword("<#Lighstreamer password#>")
        client.addDelegate(self)
        client.connect()
        self.wait(seconds: 3)
        
        // 2. Establish a subscription
        let subscription = LSSubscription(subscriptionMode: "MERGE", item: "MARKET:CS.D.EURGBP.MINI.IP", fields: ["BID","OFFER","HIGH","LOW","MID_OPEN","CHANGE","CHANGE_PCT","MARKET_DELAY","MARKET_STATE","UPDATE_TIME"])
        subscription.requestedSnapshot = "no"
        subscription.addDelegate(self)
        client.subscribe(subscription)
        self.wait(seconds: 5)

        // 3. Unsubscribe
        client.unsubscribe(subscription)
        self.wait(seconds:1)
        
        // Disconnect the Lightstreamer client
        client.removeDelegate(self)
        client.disconnect()
        self.wait(seconds: 1)
    }
    
    /// Tests account confirmation subscription using the Lightstreamer framework directly.
    func testLowlevelConfirmationSubscription() {
        // The server address is returned by the API session login.
        let client = LSLightstreamerClient(serverAddress: "<#Lightstreamer server address#>", adapterSet: nil)
        // 1. Connect the Lighstreamer client (the user is the account identifier and the password is a combination of the CST and security header).
        client.connectionDetails.user = "<#Lighstreamer user#>"
        client.connectionDetails.setPassword("<#Lighstreamer password#>")
        client.addDelegate(self)
        client.connect()
        self.wait(seconds: 1)

        // 2. Establish a subscription
        let subscription = LSSubscription(subscriptionMode: "DISTINCT", item: "TRADE:<#identifier#>", fields: ["CONFIRMS"])
        subscription.requestedSnapshot = "yes"
        subscription.addDelegate(self)
        client.subscribe(subscription)
        self.wait(seconds: 1)

        // 3. Unsubscribe
        client.unsubscribe(subscription)
        self.wait(seconds: 0.5)

        // Disconnect the Lightstreamer client
        client.removeDelegate(self)
        client.disconnect()
    }
}

extension StreamerLowlevelTests: LSClientDelegate {
//    @objc func clientDidAdd(_ client: LSLightstreamerClient) {
//        print("\(Self.self) was added as delegate for client \(client).")
//    }
//
//    @objc func client(_ client: LSLightstreamerClient, didChangeProperty property: String) {
//        print("The connection property '\(property)' has been modified.")
//    }
    
    @objc func client(_ client: LSLightstreamerClient, didChangeStatus status: String) {
        print(status)
    }
    
    @objc func client(_ client: LSLightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String?) {
        print("Error received from server with code \(errorCode) and message: \(errorMessage ?? "nil")")
    }
    
//    @objc func client(_ client: LSLightstreamerClient, willSendRequestFor challenge: URLAuthenticationChallenge) {}
//
//    @objc func clientDidRemove(_ client: LSLightstreamerClient) {
//        print("\(Self.self) was removed as delegate from client \(client).")
//    }
}

extension StreamerLowlevelTests: LSSubscriptionDelegate {
    @objc func subscriptionDidAdd(_ subscription: LSSubscription) {
        print("\(Self.self) has been added as subscription delegate.")
    }
    
    @objc func subscription(_ subscription: LSSubscription, didFailWithErrorCode code: Int, message: String?) {
        print("Subscription failed with code \(code) and message: \(message ?? "nil")")
    }
    
    @objc func subscriptionDidSubscribe(_ subscription: LSSubscription) {
        print("Subscribed successfully.")
    }
    
//    @objc func subscription(_ subscription: LSSubscription, didEndSnapshotForItemName itemName: String?, itemPos: UInt) {}
//    @objc func subscription(_ subscription: LSSubscription, didClearSnapshotForItemName itemName: String?, itemPos: UInt) {}
    
    @objc func subscription(_ subscription: LSSubscription, didUpdateItem itemUpdate: LSItemUpdate) {
        print("Update received.")
    }
    
    @objc func subscription(_ subscription: LSSubscription, didLoseUpdates lostUpdates: UInt, forItemName itemName: String?, itemPos: UInt) {
        print("\(lostUpdates) updates for item '\(itemName ?? "nil")' has been lost.")
    }
    
    @objc func subscriptionDidUnsubscribe(_ subscription: LSSubscription) {
        print("Unsubscribed.")
    }
    
    @objc func subscriptionDidRemove(_ subscription: LSSubscription) {
        print("\(Self.self) has been removed as subscription delegate.")
    }
}

#endif
