@testable import IG
import ReactiveSwift
import XCTest

extension Test {
    /// Creates an API instance from the running test account.
    static func makeAPI(scheme: Self.Account.SupportedScheme = Self.account.api.scheme,
                        rootURL: URL = Self.account.api.rootURL,
                        credentials: API.Credentials?) -> IG.API {
        switch scheme {
        case .https:
            return .init(rootURL: rootURL, credentials: credentials)
        case .file:
            return .init(rootURL: rootURL, channel: APIFileChannel(), credentials: credentials)
        }
    }
}

extension Test {
    /// Creates a streamer from the credentials stored in the test environment.
    /// - parameter autoconnect: Whether the connection shall be performed automatically within this function.
    static func makeStreamer(autoconnect: Self.Autoconnection) -> IG.Streamer {
        let rootURL = Self.account.streamer?.rootURL ?? Self.credentials.api.streamerURL
        let credentials = Self.credentials.streamer
        return Self.makeStreamer(rootURL: rootURL, credentials: credentials, autoconnect: autoconnect)
    }
    
    /// Creates a streamer instance with the given properties.
    /// - parameter rootURL: The streamer server root URL. This indicates whether it will be a file channel or a URL channel.
    /// - parameter credentials: The credentials to use to authenticate on the server.
    /// - parameter autoconnect: Whether the connection shall be performed automatically within this function.
    static func makeStreamer(rootURL: URL, credentials: IG.Streamer.Credentials, autoconnect: Self.Autoconnection) -> IG.Streamer {
        let streamer: IG.Streamer
        
        switch Self.Account.SupportedScheme(url: rootURL) {
        case .none: fatalError("The root URL is invalid. No scheme could be found.\n\(rootURL)")
        case .https:
            streamer = .init(rootURL: rootURL, credentials: credentials, autoconnect: false)
        case .file:
            let channel = StreamerFileChannel(rootURL: rootURL, credentials: credentials)
            streamer = .init(rootURL: rootURL, channel: channel, autoconnect: false)
        }
        
        if case .yes(let timeout, let queue) = autoconnect {
            do {
                try streamer.session.connect()
                    .timeout(after: timeout, on: queue) { .invalidRequest(message: "The connection timeout elapsed with status:\n\($0.debugDescription)") }
                    .wait().get()
            } catch let error {
                fatalError("\(error)")
            }
        }
        return streamer
    }

    /// Enumeration indicating whether autoconnection is desired or not.
    enum Autoconnection {
        /// An automatic connection attempt shall be applied with a given timeout in a given queue.
        case yes(timeout: TimeInterval, queue: DateScheduler)
        /// The connection will be performed manually later on.
        case no
    }
}

