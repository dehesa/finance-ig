<p align="center">
    <img src="Assets/IG.svg" alt="Codable CSV"/>
</p>

![Swift 5](https://img.shields.io/badge/Swift-5-orange.svg) ![platforms](https://img.shields.io/badge/platforms-macOS-lightgrey.svg) [![License](http://img.shields.io/:license-mit-blue.svg)](http://doge.mit-license.org)

This framework provides:
- Interface to IG's **HTTP APIs and Lightstreamer service**.
- Session management helpers.
- **ReactiveSwift support** for easy endpoint pipelining.

Usage
=====

The easiest way to start interfacing with the IG platform is initializing a `Services` instance. To be able to initialize one, you will need the following:
- an *API key*.
  You can get one from someone that has an IG application, or you can [generate your own](https://labs.ig.com/gettingstarted); e.g. `a12345bc67890d12345e6789fg0hi123j4567890`.
- Information for the user you will be logged in as.
  - Account Identifier.
    The targeted user's account identifier; e.g. `ABC12`.
  - Username.
    The targeted user's platform name; e.g. `fake_mcfakerson`
  - User Password.
    The targeted user's password. Whatever password you use to log in [ig.com](https://www.ig.com).
    If you are uneasy pasting your password, you can use your OAuth or Certificate tokens. To know more, please check the [HTTP API / Signing In](#Signing-In) section.

```swift
let info = try API.Request.Login(apiKey: "...", accountId: "...", username: "...", password: "...")

Services.make(loginInfo: info).startWithResult {
    guard let services = $0.value else { /* Check the error */ }
    // Send the platform object wherever you want.
}
```

A `Services` instance has completely functional HTTP and Lightstreamer services. Both these services are initialized and ready to operate.
```swift
let services: Services = // Previously obtained `Services` instance

services.api.session().startWithValues { (session) in
    print("Logged client identifier: \(session.clientId)")
    print("Logged account identifier: \(session.accountId)")
    print("Current locale: \(session.locale)")
}

services.streamer.subscribe(market: "CS.D.EURUSD.MINI.IP", fields: [.bid, .offer, .date]).startWithValues {
    print("Date: \($0.date!)")
    print("Offer: \($0.price.offer!)")
    print("Bid: \($0.price.bid!)")
}
```

HTTP API
--------

The HTTP service provided by this framework lets you call all endpoints listed in [labs.ig.com/rest-trading-api-reference](https://labs.ig.com/rest-trading-api-reference). All endpoints offer compile-time interfaces for Swift and use Standard or Foundation types (no more confusing ways to write dates).

For example, to query the historical prices for a particular instrument.
```swift
let beginning = Date(timeIntervalSinceNow: -60 * 60 * 4)

services.api.prices(epic: "CS.D.EURUSD.MINI.IP", from: beginning, to: Date(), resolution: .minute).startWithValues {
    for price in $0.prices {
        print("Highest: \(price.highest.offer)-\(price.highest.bid)")
        print("Lowest: \(price.lowest.offer)-\(price.lowest.bid)")
    }
}
```

### Signing In
You can log in with OAuth or Certificate tokens (this latest is recommended). If you are using the `Services` helper, you don't need to worry about any of these; but if you want to instantiate an `API` object by yourself you need to specify the type of credentials used.

```swift
let tokenType: API.Credentials.Token.Kind = .certificate(access: "...", security: "...")
let credentials = API.Credentials(
    clientId: "...", accountId: "...", apiKey: "...",
    token: .init(tokenType, expirationDate: ...),
    streamerURL: "...", timeZone: ...)

let api = API(rootURL: "https://api.ig.com/gateway/deal", credentials: credentials)
```

Lightstreamer
-------------

Lightstreamer events are fully supported. As soon as you get hold of a `Streamer` instance you can subscribe to all your targeted events. Please be mindful of the [limits enforced by IG](https://labs.ig.com/faq#limits).

You can subscribe to any of the [exposed endpoints](https://labs.ig.com/streaming-api-reference). As with the HTTP service, this framework offer compile-time interfaces for Swift and use Standard and/or Foundation types.

Lets, for example subscribe to all event trades of a given account.
```swift
services.streamer.subscribe(account: "ABC12", updates: [.confirmations]).startWithValues {
    guard let confirmation = $0.confirmation else { /* Handle this */ }
    print("Identifier: \(confirmation.identifier)")
    print("Reference: \(confirmation.reference)")
    print("Date: \(confirmation.date)")
    print("is accepted: \(confirmation.isAccepted)")
}
```

Installation
============

This framework has the following dependencies:
- [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift).
- [Lightstreamer](https://lightstreamer.com/download/).
  IG only supports an older version from the Lightstreamer framework. Check  [labs.ig.com](https://labs.ig.com/lightstreamer-downloads) for information on the latest Lightstreamer version supported.

To hold this framework binaries you have two options.
- Grab the `.framework` file for the platform of your choice from [the Github releases page](https://github.com/dehesa/IG/releases).
    - Download the framework file to your computer.
    - Drag-and-drop it within your project.
    - If you are using Xcode, drag-and-drop the framework in `Linked Frameworks & Libraries` and don't forget to add the dependencies there either.
- Clone and build with Xcode.
    - Clone the git project: `git clone --recursive git@github.com:dehesa/IG.git`
    - Go inside the ReactiveSwift folder `cd IG/Dependencies/ReactiveSwift` and run `git submodule update --init --recursive`
    - Open the `IG.xcworkspace` with Xcode.
    - Select the build scheme for your targeted platform (e.g. `IG [macOS]`).
    - Product > Build (or keyboard shortcut `⌘+B`).
    - Open the project's `Products` folder and drag-and-drop the built framework in your project (or right-click in it and `Show in Finder`).

Roadmap
=======

- [x] Map all HTTP endpoints.
- [x] Map all streamer events.
- [x] Support different ways to sign in.
- [x] Create `Services` helper.
- [x] Test all HTTP endpoints.
- [ ] Test all streamer events.
- [ ] Optimize endpoint calls.
- [ ] Support iOS, tvOS, watchOS.
- [ ] Support Linux.
