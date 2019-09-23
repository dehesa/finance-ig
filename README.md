<p align="center">
    <img src="Assets/IG.svg" alt="Codable CSV"/>
</p>

![Swift 5.1](https://img.shields.io/badge/Swift-5.1-orange.svg) ![platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS-lightgrey.svg) ![Xcode 11](https://img.shields.io/badge/Xcode-11-blueviolet.svg) [![License](http://img.shields.io/:license-mit-blue.svg)](http://doge.mit-license.org)

This framework provides:

-   Swift interface to IG's HTTP APIs.
-   Swift interface to IG's Lightstreamer service.
    <br>The Lighstreamer binaries are packaged with the source code. IG only supports an older version from the Lightstreamer framework and this framework will provide the latest supported version. To know more, check [labs.ig.com](https://labs.ig.com/lightstreamer-downloads).
-   Session management helpers.
-   [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift) support for easy endpoint pipelining.
    <br>Dependency provided through Swift Package Manager.

# Usage

To access your IG account you can:

-   create an `API` instance, or
-   create a `Streamer` instance, or
-   create a `Services` instance (which will take care of the previous instance for yourself).

The easiest way is thus, to create a `Services` instance and get a hold to it. To log in, you need:

-   an _API key_.
    You can get one from someone that has an IG application, or you can [generate your own](https://labs.ig.com/gettingstarted); e.g. `a12345bc67890d12345e6789fg0hi123j4567890`.
-   Information for the user you will be logged in as.
    You can log in with your actual credentials.

    ```swift
    let user = API.User(name: "username", password: "password")
    let apiKey = "a12345bc67890d12345e6789fg0hi123j4567890"
    var services = Services.make(key: apiKey, user: user).single()!.get()
    ```

    Or you can log in with an OAuth token or Certificate token.

    ```swift
    let oauthAccess =  "toa7770m-1915-83u4-q665-80g574lm7659"
    let oauthRefresh = "rho2072f-4006-17t8-n417-42j560hw5130"
    let apiKey = "a12345bc67890d12345e6789fg0hi123j4567890"
    let token = API.Credentials.Token(.oauth(access: oauthAccess, refresh: oauthRefresh, scope: "profile", type: "Bearer"), .expiresIn: 60))
    var services = Services.make(key: apiKey, token: token).single()!.get()
    ```

A `Services` instance has completely functional HTTP and Lightstreamer services. Both these services are initialized and ready to operate.

```swift
let transactions = services.api.transactions.get(from: .yesterday: to: Date()).single()!.get()
print("Between yesterday and today, there were \(transactions.count) transactions")
for transaction in transactions {
    print(transaction.profitLoss)
}

services.streamer.markets.subscribe(to: "CS.D.EURUSD.MINI.IP", fields: [.bid, .offer, .date]).startWithValues {
    print("Date: \($0.date!)")
    print("Offer: \($0.price.offer!)")
    print("Bid: \($0.price.bid!)")
}
```

## HTTP API

The HTTP service provided by this framework lets you call all endpoints listed in [labs.ig.com/rest-trading-api-reference](https://labs.ig.com/rest-trading-api-reference). All endpoints offer compile-time interfaces for Swift and use Standard or Foundation types (no more confusing ways to write dates).

For example, to query the historical prices for a particular instrument.

```swift
let startDate = Date(timeIntervalSinceNow: -60 * 60 * 4)

services.api.prices(epic: "CS.D.EURUSD.MINI.IP", from: startDate, to: Date(), resolution: .minute).startWithValues {
    for price in $0.prices {
        print("Highest: \(price.highest.ask)")
        print("Lowest: \(price.lowest.ask)")
    }
}
```

## Lightstreamer

Lightstreamer events are fully supported. As soon as you get hold of a `Streamer` instance you can subscribe to all your targeted events. Please be mindful of the [limits enforced by IG](https://labs.ig.com/faq#limits).

You can subscribe to any of the [exposed endpoints](https://labs.ig.com/streaming-api-reference). As with the HTTP service, this framework offer compile-time interfaces for Swift and use Standard and/or Foundation types.

Lets, for example subscribe to all event trades of a given account.

```swift
services.streamer.confirmations.subscribe(to: "ABC12").startWithValues {
    guard let confirmation = $0.confirmation else { /* Handle this */ }
    print("Identifier: \(confirmation.identifier)")
    print("Reference: \(confirmation.reference)")
    print("Date: \(confirmation.date)")
    print("is accepted: \(confirmation.isAccepted)")
}
```

# Roadmap

-   [x] Map all HTTP endpoints.
-   [x] Map all streamer events.
-   [x] Support OAuth & Certificate to sign in.
-   [x] Create `Services` helper.
-   [x] Test all HTTP endpoints.
-   [x] Test all streamer events.
-   [x] Support iOS.
-   [x] Add SQLite database.
-   [ ] Migrate from ReactiveSwift to Combine.
-   [ ] Interconnect services.
