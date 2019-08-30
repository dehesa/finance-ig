import GRDB
import Foundation

/// The Database instance is the bridge between the internal SQLite storage
public final class Database {
    /// File URL where the database is found.
    ///
    /// If `nil` the database is created "in memory".
    public let rootURL: URL?
    /// The underlying instance (whether real or mocked) actually storing/reading the information.
    internal let channel: GRDB.DatabaseQueue
    
    /// Creates a database instance fetching and storing values from/to the given location.
    /// 
    /// - parameter rootURL: The file location or `nil` for "in memory" storage.
    /// - throws: `IG.Database.Error`
    public convenience init(rootURL: URL?) throws {
        try self.init(rootURL: rootURL, configuration: Self.defaultConfiguration)
    }
    
    /// Designated initializer for the database instance providing the database configuration.
    /// - parameter rootURL: The file URL where the databse file is or `nil` for "in memory" storage.
    /// - parameter configuration: The SQLite database configuration.
    /// - throws: `IG.Database.Error`
    internal init(rootURL: URL?, configuration: GRDB.Configuration) throws {
        self.rootURL = rootURL
        
        guard let url = rootURL else {
            self.channel = .init(configuration: configuration)
            return
        }
        
        guard url.isFileURL else {
            let message = #"The database url given for the database location "\#(url)" is not a valid file URL."#
            var error: IG.Database.Error = .invalidRequest(message, suggestion: #"Make sure that the URL is of the "file://" domain."#)
            error.context.append(("rootURL", url))
            throw error
        }
        
        let manager = FileManager.default
        do {
            if !manager.fileExists(atPath: url.deletingLastPathComponent().path, isDirectory: nil) {
                try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            }
            
            self.channel = try .init(path: url.path, configuration: configuration)
        } catch let error {
            throw IG.Database.Error.invalidRequest("The SQLite file couldn't be opened (or created).", underlying: error, suggestion: "Make sure the rootURL is a valid and try again")
        }
    }
}

extension IG.Database {
    /// The root address for the underlying database file.
    public static var rootURL: URL {
        let result: URL
        do {
            result = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        } catch let error {
            fatalError(#"The "documents" folder in the user domain couldn't be retrieved in this system.\nUnderlying error: \#(error)"#)
        }
        return result.appendingPathComponent("IG.sqlite")
    }
    
    /// Default configuration for the underlying SQLite database.
    internal static var defaultConfiguration: GRDB.Configuration {
        var configuration = GRDB.Configuration()
        configuration.label = Bundle(for: Database.self).bundleIdentifier! + ".db"
        return configuration
    }
}
