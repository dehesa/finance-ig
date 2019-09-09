@testable import IG
import ReactiveSwift
import XCTest

extension Test {
    /// Creates an API instance from the running test account.
    /// - precondition: This function expect the root URL to be valid or the test will crash.
    /// - parameter rootURL: The server root URL where the endpoints will be based from.
    /// - parameter credentials: The starting credentials for the API instance.
    /// - parameter targetQueue: The target queue on which to process the `API` requests and responses.
    /// - returns: A fully initialized `API` instance.
    static func makeAPI(rootURL: URL, credentials: API.Credentials?, targetQueue: DispatchQueue?) -> IG.API {
        switch Test.Account.SupportedScheme(url: rootURL) {
        case .https:
            return .init(rootURL: rootURL, credentials: credentials, targetQueue: targetQueue)
        case .file:
//            let configuration = API.defaultSessionConfigurations
//            configuration.protocolClasses = [APIFileProtocol.self]
//            return .init(rootURL: rootURL, credentials: credentials, configuration: configuration)
            fatalError()
        case .none:
            fatalError(#"The API rootURL "\#(rootURL)" is invalid"#)
        }
    }
}

extension Test {
    /// Creates a streamer instance with the given properties.
    /// - parameter rootURL: The streamer server root URL. This indicates whether it will be a file channel or a URL channel.
    /// - parameter credentials: The credentials to use to authenticate on the server.
    /// - parameter targetQueue: The target queue on which to process the `Streamer` requests and responses.
    /// - parameter autoconnect: Whether the connection shall be performed automatically within this function.
    static func makeStreamer(rootURL: URL, credentials: IG.Streamer.Credentials, targetQueue: DispatchQueue?, autoconnect: Self.Autoconnection) -> IG.Streamer {
        let streamer: IG.Streamer
        
        switch Self.Account.SupportedScheme(url: rootURL) {
        case .none: fatalError("The root URL is invalid. No scheme could be found.\n\(rootURL)")
        case .https:
            streamer = .init(rootURL: rootURL, credentials: credentials, targetQueue: targetQueue, autoconnect: false)
        case .file:
//            let channel = StreamerFileChannel(rootURL: rootURL, credentials: credentials)
//            streamer = .init(rootURL: rootURL, channel: channel, autoconnect: false)
            fatalError()
        }
        
        if case .yes(let timeout, let queue) = autoconnect {
            do {
                try streamer.session.connect()
                    .timeout(after: timeout, on: queue) {
                        .invalidRequest("The connection timeout elapsed with status:\n\($0.debugDescription)", suggestion: "Be sure to be connected to the internet and that the credentials for the test account are appropriate. If so, try again later or contact the repository maintainer")
                    }.wait().get()
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

extension Test {
    /// Creates a database from the
    /// - precondition: The `rootURL` is expected to be a valid URL or `nil`. In any other case, the test will crash.
    /// - parameter rootURL: The file location or nil for “in memory” storage.
    /// - parameter targetQueue: The target queue on which to process the `DB` requests and responses.
    /// - returns: A fully ready database.
    static func makeDatabase(rootURL: URL?, targetQueue: DispatchQueue?) -> IG.DB {
        do {
            return try .init(rootURL: rootURL, targetQueue: targetQueue)
        } catch let error {
            fatalError(String(describing: error))
        }
    }
}
