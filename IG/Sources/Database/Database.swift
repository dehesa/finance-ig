import Combine
import SQLite3

/// The Database instance is the bridge between the internal SQLite storage
public final class Database {
    /// File URL where the database is found.
    ///
    /// If `nil` the database is created "in memory".
    public final var rootURL: URL? { self.channel.rootURL }
    /// The queue processing and delivering database values.
    internal final let queue: DispatchQueue
    /// The underlying instance (whether real or mocked) actually storing/reading the information.
    internal final let channel: IG.Database.Channel
    
    /// Namespace for functionality related to user accounts.
    public final var accounts: IG.Database.Request.Accounts { return .init(database: self) }
    /// Namespace for functionality related to IG's markets.
    public final var markets: IG.Database.Request.Markets { return .init(database: self) }
    /// Namespace for functionality related to price data points.
    public final var price: IG.Database.Request.Price { return .init(database: self) }
    
    /// The database version.
    public final var version: Int { return IG.Database.Migration.Version.latest.rawValue }
    /// The version of SQLite being used.
    public final var sqliteVersion: String { return SQLITE_VERSION }
    
    /// Creates a database instance fetching and storing values from/to the given location.
    /// - parameter location: The location of the database (whether "in-memory" or file system).
    /// - parameter targetQueue: The target queue on which to process the `Database` requests and responses.
    /// - throws: `IG.Database.Error` exclusively.
    public convenience init(location: IG.Database.Location, targetQueue: DispatchQueue?) throws {
        let processingQueue = targetQueue ??
            DispatchQueue(label: Self.reverseDNS + ".queue", qos: .utility, attributes: .concurrent, autoreleaseFrequency: .inherit, target: targetQueue)
        let channel = try Self.Channel(location: location, targetQueue: targetQueue)
        try self.init(channel: channel, queue: processingQueue)
    }
    
    /// Designated initializer for the database instance providing the database configuration.
    /// - parameter rootURL: The file URL where the databse file is or `nil` for "in memory" storage.
    /// - parameter channel: The SQLite opaque pointer to the database.
    /// - parameter queue: The queue on which to process the `Database` requests and responses.
    /// - throws: `IG.Database.Error` exclusively.
    internal init(channel: IG.Database.Channel, queue: DispatchQueue) throws {
        self.channel = channel
        self.queue = queue
        try self.migrateToLatestVersion()
    }
}

extension IG.Database {
    /// The database location.
    public enum Location {
        /// The database will be created for this session in memory. At the end of the session it will be flushed.
        case inMemory
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
    public static var rootURL: URL {
        let result: URL
        do {
            result = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        } catch let error {
            fatalError(#"The "documents" folder in the user domain couldn't be retrieved in this system.\nUnderlying error: \#(error)"#)
        }
        return result.appendingPathComponent("IG.sqlite")
    }
    
    /// The reverse DNS identifier for the `DB` instance.
    internal static var reverseDNS: String {
        return Bundle.IG.identifier + ".db"
    }
}

extension IG.Database: DebugDescriptable {
    internal static var printableDomain: String { "\(Bundle.IG.name).\(Self.self)" }
    
    public final var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("root URL", self.rootURL.map { $0.path } ?? ":memory:")
        result.append("queue", self.queue.label)
        result.append("queue QoS", String(describing: self.queue.qos.qosClass))
        result.append("version", IG.Database.Migration.Version.latest.rawValue)
        result.append("SQLite", SQLITE_VERSION)
        return result.generate()
    }
}
