import Combine
import SQLite3
import Foundation

/// The Database instance is the bridge between the internal SQLite storage
public final class Database {
    /// File URL where the database is found.
    ///
    /// If `nil` the database is created "in memory".
    public final var rootURL: URL? { self.channel.rootURL }
    /// The queue processing and delivering database values.
    internal final let queue: DispatchQueue
    /// The underlying instance (whether real or mocked) actually storing/reading the information.
    internal final let channel: Database.Channel
    
    /// Namespace for functionality related to user accounts.
    @inlinable public final var accounts: Database.Request.Accounts { .init(database: self) }
    /// Namespace for functionality related to IG's markets.
    @inlinable public final var markets: Database.Request.Markets { .init(database: self) }
    /// Namespace for functionality related to price data points.
    @inlinable public final var prices: Database.Request.Prices { .init(database: self) }
    
    /// The database version.
    public final var version: Int { Database.Version.latest.rawValue }
    /// The version of SQLite being used.
    public final var sqliteVersion: String { SQLITE_VERSION }
    
    /// Creates a database instance fetching and storing values from/to the given location.
    ///
    /// - precondition: `targetQueue` cannot be set to `DispatchQueue.main` no to a queue which ultimately executes blocks on `DispatchQueue.main`.  Also, the initializer cannot be called from within the `targetQueue` execution context.
    ///
    /// - parameter location: The location of the database (whether "in-memory" or file system).
    /// - parameter queue: The queue on which to process the `Database` requests and responses. If `nil`, an appropriate queue will be created.
    /// - throws: `IG.Error` exclusively.
    public convenience init(location: Database.Location, queue: DispatchQueue? = nil) throws {
        let queue = queue ?? DispatchQueue(label: IG.identifier + ".database.queue", qos: .utility, attributes: .concurrent, target: queue)
        let channel = try Database.Channel(location: location, targetQueue: queue)
        try self.init(channel: channel, queue: queue)
    }
    
    /// Designated initializer for the database instance providing the database configuration.
    /// - parameter rootURL: The file URL where the databse file is or `nil` for "in memory" storage.
    /// - parameter channel: The SQLite opaque pointer to the database.
    /// - parameter queue: The queue on which to process the `Database` requests and responses.
    /// - throws: `IG.Error` exclusively.
    internal init(channel: Database.Channel, queue: DispatchQueue) throws {
        self.channel = channel
        self.queue = queue
        try self.migrateToLatestVersion()
    }
}

extension Database {
    /// The database location.
    public enum Location {
        /// The database will be created for this session in memory. At the end of the session it will be flushed.
        case memory
        /// The database will be located in the file system (at the given path).
        ///
        /// The following cases are supported:
        /// - If `expectsExistance` is `true`, the database must be in the given location or an error will be thrown.
        /// - If `expectsExistance` is `false`, there must NOT be any database in the file system. Therefore, a new one will be created.
        /// - If `expectsExistance` is `nil`, there may or may not be a database in the given location. In case, there is a database, that one will be used. In case there is none, a new one will be created.
        ///
        /// Please notice, that there isn't a situation where the database is rewritten. If you want to replace a database, you need to delete it manually first.
        case file(url: URL, expectsExistance: Bool?)
    }
    
    /// The root address for the underlying database file.
    @_transparent public static var rootURL: URL {
        let result: URL
        do {
            result = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        } catch let error {
            fatalError("The 'documents' folder in the user domain couldn't be retrieved in this system.\nUnderlying error: \(error)")
        }
        return result.appendingPathComponent("IG.sqlite")
    }
}
