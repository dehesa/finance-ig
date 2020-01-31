@testable import IG
import XCTest

extension Test {
    /// Creates an API instance with the given data.
    /// - precondition: This function expect the root URL to be valid or the test will crash.
    /// - parameter rootURL: The server root URL where the endpoints will be based from.
    /// - parameter credentials: The starting credentials for the API instance.
    /// - parameter targetQueue: The target queue on which to process the `API` requests and responses.
    /// - returns: A fully initialized `API` instance.
    /// - todo: Support API & Streamer File tests
    static func makeAPI(rootURL: URL, credentials: API.Credentials?, targetQueue: DispatchQueue?, file: StaticString = #file, line: UInt = #line) -> IG.API {
        switch Test.Account.SupportedScheme(url: rootURL) {
        case .https:
            return .init(rootURL: rootURL, credentials: credentials, targetQueue: targetQueue)
        case .file:
//            let configuration = API.defaultSessionConfigurations
//            configuration.protocolClasses = [APIFileProtocol.self]
//            return .init(rootURL: rootURL, credentials: credentials, configuration: configuration)
            fatalError(file: file, line: line)
        case .none:
            fatalError(#"The API rootURL "\#(rootURL)" is invalid"#, file: file, line: line)
        }
    }
}

extension Test {
    /// Creates a streamer instance with the given properties.
    /// - parameter rootURL: The streamer server root URL. This indicates whether it will be a file channel or a URL channel.
    /// - parameter credentials: The credentials to use to authenticate on the server.
    /// - parameter targetQueue: The target queue on which to process the `Streamer` requests and responses.
    /// - parameter autoconnect: Whether the connection shall be performed automatically within this function.
    static func makeStreamer(rootURL: URL, credentials: IG.Streamer.Credentials, targetQueue: DispatchQueue?, file: StaticString = #file, line: UInt = #line) -> IG.Streamer {
        let streamer: IG.Streamer

        switch Self.Account.SupportedScheme(url: rootURL) {
        case .https:
            streamer = .init(rootURL: rootURL, credentials: credentials, targetQueue: targetQueue)
        case .file:
//            let channel = StreamerFileChannel(rootURL: rootURL, credentials: credentials)
//            streamer = .init(rootURL: rootURL, channel: channel, autoconnect: false)
            fatalError(file: file, line: line)
        case .none:
            fatalError("The root URL is invalid. No scheme could be found.\n\(rootURL)", file: file, line: line)
        }
        
        return streamer
    }

    /// Enumeration indicating whether autoconnection is desired or not.
    enum Autoconnection: ExpressibleByNilLiteral {
        /// An automatic connection attempt shall be applied with a given timeout.
        case autoconnect(timeout: DispatchTimeInterval = .seconds(4))
        /// The connection will be performed manually later on.
        case still
        
        init(nilLiteral: ()) {
            self = .still
        }
    }
}

extension Test {
    /// Creates a database from the
    /// - precondition: The `rootURL` is expected to be a valid URL or `nil`. In any other case, the test will crash.
    /// - parameter rootURL: The file location or nil for “in memory” storage.
    /// - parameter targetQueue: The target queue on which to process the `Database` requests and responses.
    /// - returns: A fully ready database.
    static func makeDatabase(rootURL: URL?, targetQueue: DispatchQueue?) -> IG.Database {
        do {
            return try .init(location: rootURL.map { .file(url: $0, expectsExistance: nil) } ?? .inMemory, targetQueue: targetQueue)
        } catch let error {
            fatalError(String(describing: error))
        }
    }
}
