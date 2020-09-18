import XCTest
#if os(macOS)
import Lightstreamer_macOS_Client
#elseif os(iOS)
import Lightstreamer_iOS_Client
#else
#error("OS currently not supported")
#endif
import ConbiniForTesting
import Foundation

final class StreamerLowlevelTests: XCTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }
    
    /// Test the subscription to the market using the Lightstreamer framework directly.
    func testLowlevelMarketSubscription() {
        // 1. Connect the Lighstreamer client
        let client = LSLightstreamerClient(serverAddress: "<#Lightstreamer server address#>", adapterSet: nil)
        client.connectionDetails.user = "<#Lighstreamer user#>"
        client.connectionDetails.setPassword("<#Lighstreamer password#>")
        client.add(delegate: self)
        client.connect()
        self.wait(seconds: 1)
        
        // 2. Establish a subscription
        let subscription = LSSubscription(mode: "MERGE", item: "MARKET:CS.D.EURGBP.MINI.IP", fields: ["BID","OFFER","HIGH","LOW","MID_OPEN","CHANGE","CHANGE_PCT","MARKET_DELAY","MARKET_STATE","UPDATE_TIME"])
        subscription.requestedSnapshot = "no"
        subscription.add(delegate: self)
        client.subscribe(subscription)
        self.wait(seconds: 3)
        
        // 3. Unsubscribe
        client.unsubscribe(subscription)
        self.wait(seconds: 0.5)
        
        // Disconnect the Lightstreamer client
        client.remove(delegate: self)
        client.disconnect()
    }
    
    /// Tests account confirmation subscription using the Lightstreamer framework directly.
    func testLowlevelConfirmationSubscription() {
        // 1. Connect the Lighstreamer client
        let client = LSLightstreamerClient(serverAddress: "<#Lightstreamer server address#>", adapterSet: nil)
        client.connectionDetails.user = "<#Lighstreamer user#>"
        client.connectionDetails.setPassword("<#Lighstreamer password#>")
        client.add(delegate: self)
        client.connect()
        self.wait(seconds: 1)
        
        // 2. Establish a subscription
        let subscription = LSSubscription(mode: "DISTINCT", item: "TRADE:<#identifier#>", fields: ["CONFIRMS"])
        subscription.requestedSnapshot = "yes"
        subscription.add(delegate: self)
        client.subscribe(subscription)
        self.wait(seconds: 1)
        
        // 3. Unsubscribe
        client.unsubscribe(subscription)
        self.wait(seconds: 0.5)
        
        // Disconnect the Lightstreamer client
        client.remove(delegate: self)
        client.disconnect()
    }
}

extension StreamerLowlevelTests: LSClientDelegate {
    @objc func client(_ client: LSLightstreamerClient, didChangeStatus status: String) {
        print(status)
    }
//    @objc func client(_ client: LSLightstreamerClient, didChangeProperty property: String) { <#code#> }
//    @objc func client(_ client: LSLightstreamerClient, willSendRequestFor challenge: URLAuthenticationChallenge) { <#code#> }
//    @objc func client(_ client: LSLightstreamerClient, didReceiveServerError errorCode: Int, withMessage errorMessage: String?) { <#code#> }
//    @objc func didAddDelegate(to: LSLightstreamerClient) { <#code#> }
//    @objc func didRemoveDelegate(to: LSLightstreamerClient) { <#code#> }
}

extension StreamerLowlevelTests: LSSubscriptionDelegate {
    @objc func didSubscribe(to subscription: LSSubscription) {
        print("subscribed")
    }
    
    @objc func didUnsubscribe(from subscription: LSSubscription) {
        print("unsubscribed")
    }
    
    @objc func didFail(_ subscription: LSSubscription, errorCode code: Int, message: String?) {
        var info = "failed with code \(code)"
        if let msg = message { info.append(" and message '\(msg)'") }
        print(info)
    }
    
    @objc func didUpdate(_ subscription: LSSubscription, item itemUpdate: LSItemUpdate) {
        print("received update")
    }
    
    @objc func didLoseUpdates(_ subscription: LSSubscription, count lostUpdates: UInt, itemName: String?, itemPosition itemPos: UInt) {
        print("lost \(lostUpdates) updates")
    }
//    @objc func didAddDelegate(to subscription: LSSubscription) {}
//    @objc func didRemoveDelegate(from subscription: LSSubscription) {}
//    @objc func subscription(_ subscription: LSSubscription, didEndSnapshotForItemName itemName: String?, itemPos: UInt) {}
//    @objc func subscription(_ subscription: LSSubscription, didClearSnapshotForItemName itemName: String?, itemPos: UInt) {}
}

