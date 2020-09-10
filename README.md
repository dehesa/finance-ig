<p align="center">
    <img src="docs/assets/IG.svg" alt="Framework Logo"/>
</p>

<p align="center">
    <a href="https://swift.org/about/#swiftorg-and-open-source"><img src="docs/assets/badges/Swift.svg" alt="Swift 5.2"></a>
    <a href="https://github.com/dehesa/CodableCSV/wiki/Implicit-dependencies"><img src="docs/assets/badges/Apple.svg" alt="macOS 10.15+ - iOS 13+"></a>
    <a href="https://developer.apple.com/xcode"><img src="docs/assets/badges/Xcode.svg" alt="Xcode 11"></a>
    <a href="http://doge.mit-license.org"><img src="docs/assets/badges/License.svg" alt="MIT License"></a>
</p>

This framework provides:

-   All public [HTTP IG endpoints](https://labs.ig.com/rest-trading-api-reference) (with request, response, and error handling support).
-   All public [Lightstreamer IG subscriptions](https://labs.ig.com/streaming-api-reference) (with request, response, and error handling support).
    <br>The [Lighstreamer binaries](https://labs.ig.com/lightstreamer-downloads) are packaged with the source code. IG only supports an older Lightstreamer version and this framework provides exactly that version.
-   Session management helpers (such as OAuth and Certificate token refreshes, etc).
-   Optional small SQLite database to cache market and price information.
-   Currency and optional _Money_ types.

# Usage

To use this framework you just need to include `IG.xcodeproj` in your Xcode project/workspace. Then import the framework in any file that needs it. SPM support will arrive with Swift 5.3 ([SE-271](https://github.com/apple/swift-evolution/blob/master/proposals/0271-package-manager-resources.md) and [SE-272](https://github.com/apple/swift-evolution/blob/master/proposals/0272-swiftpm-binary-dependencies.md) will permit binary inclusion required for the Lightstreamer library).

```swift
import IG
```

The IG framework uses the Swift Standard Library, Foundation, Combine, and the host system SQLite library. All these are provided implictly. There is also a SPM file defining the following third-party dependencies:
-   [Decimals](https://github.com/dehesa/Decimal64) (for a more performant 64-bit decimal number type).
-   [Conbini](https://www.github.com/dehesa/Conbini) (for extra functionality for Combine).

## API

All public HTTP endpoints are defined under the `API` reference type. To expose the functionality:
1. Create an API instance.

    ```swift
    let api = API()
    // Optionally you can pass the demo rootURL: API(rootURL: API.demoRootURL)
    ```

2. Log into an account.

    ```swift
    let key: API.Key = "a12345bc67890d12345e6789fg0hi123j4567890"
    let user = API.User(name: "username", password: "password")
    api.sessions.login(type: .certificate, key: key, user: user)
    ```

    To generate your own API key, look [here](https://labs.ig.com/gettingstarted).

3. Call a specific endpoint.

    ```swift
    // As an example, lets get information about the EURUSD forex mini market.
    api.markets.get(epic: "CS.D.EURUSD.MINI.IP")
    ```

It is worth noticing that all the endpoints are asynchronous (they must call the server and receive a response). That is why this framework relies heavily in Combine and most functions return a `Publisher` type that can be chained with further endpoints. For example:

```swift
let api = API(rootURL: API.rootURL, credentials: nil)
let cancellable = api.sessions.login(type: .certificate, key: key, user: user)
    .then {
        api.markets.get(epic: "CS.D.EURUSD.MINI.IP")
    }.flatMap {
        api.prices.get(epic: $0.instrument.epic, from: Date(timeIntervalSinceNow: -3_600), resolution: .minute)
    }.sink(receiveCompletion: {
        guard case .finished = $0 else { return print($0) }
    }, receiveValue: { (prices) in
        prices.forEach { print($0) }
    })
```

The login process only needs to be called once, since the temporary token is stored within the api object. Make sure you keep the API instance around while you are using API functionality. IG permits the usage of OAuth or Certificate tokens. Although both work with any API endpoint, there are some differences:
- OAuth tokens are only valid for 60 seconds, while Certificate tokens usually last for 6 hours.
- It is not possible to request Lightstreamer credentials with OAuth tokens.

For those reasons, it is recommended to use to Certificate tokens.

## Streamer

All public Lightstreamer subscriptions are defined under the `Streamer` reference type. To expose the functionality.

1. Retrieve the streamer credentials and initialize a `Streamer` instance.

    ```swift
    guard let apiCreds = api.session.credentials else { return }
    let streamerCreds = try Streamer.Credentials(apiCreds)
    let streamer = Streamer(rootURL: apiCreds.streamerURL, credentials: streamerCreds)
    ```

2. Connect the streamer.

    ```swift
    streamer.sessions.connect()
    ```

3. Subscribe to any targeted event.

    ```swift
    streamer.prices.subscribe(epic: "CS.D.EURUSD.MINI.IP", interval: .minute, fields: .all)
    ```

    The returned publisher will forward events till the publisher is cancelled.

> Please be mindful of the [limits enforced by IG](https://labs.ig.com/faq#limits).

## Database

The library provides the option to create a SQLite database to cache market information and/or price data. This is a _work in progress_ and it currently only support forex markets and price resolutions of one minute.

1. Define a database location.

    ```swift
    let db = try Database(location: .inMemory)
    ```

2. Write some API market data.

    ```swift
    db.markets.update(apiMarket)
    ```

3. Write some API prices.

    ```swift
    db.prices.update(apiPrices, epic: "CS.D.EURUSD.MINI.IP")
    ```

## Services

You can cherry pick which service to use; however, it might be simpler to let the convenience `Services` initialize all subservices for you.

1. Get credentials.

    ```swift
    let user: API.User = .init(name: "username", password: "password")
    let apiKey: API.Key = "a12345bc67890d12345e6789fg0hi123j4567890"
    ```

2. Create a services aggregator.

    ```swift
    let services = Services.make(key: apiKey, user: user)
    ```

A `Services` instance has completely functional HTTP, Lightstreamer services, and SQLite database. All these services are initialized and ready to operate.
