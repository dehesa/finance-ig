import Combine
import SQLite3

/// The Database instance is the bridge between the internal SQLite storage
public final class DB {
    /// File URL where the database is found.
    ///
    /// If `nil` the database is created "in memory".
    public final let rootURL: URL?
    /// The queue processing and delivering database values.
    internal final let queue: DispatchQueue
    /// The underlying instance (whether real or mocked) actually storing/reading the information.
    internal final let channel: IG.DB.Channel
    
    /// Namespace for functionality related to user accounts.
    public final var accounts: IG.DB.Request.Accounts { return .init(database: self) }
    /// Namespace for functionality related to IG's markets.
    public final var markets: IG.DB.Request.Markets { return .init(database: self) }
    /// Namespace for functionality related to price data points.
    public final var price: IG.DB.Request.Price { return .init(database: self) }
    
    /// The database version.
    public final var version: Int { return IG.DB.Migration.Version.latest.rawValue }
    /// The version of SQLite being used.
    public final var sqliteVersion: String { return SQLITE_VERSION }
    
    /// Creates a database instance fetching and storing values from/to the given location.
    /// - parameter rootURL: The file location or `nil` for "in memory" storage.
    /// - parameter targetQueue: The target queue on which to process the `DB` requests and responses.
    /// - throws: `IG.DB.Error` exclusively.
    public convenience init(rootURL: URL?, targetQueue: DispatchQueue?) throws {
        let qos = targetQueue?.qos ?? .utility
        let priviledgeQueue = DispatchQueue(label: Self.reverseDNS + ".priviledge", qos: qos, /*attributes: .concurrent,*/ autoreleaseFrequency: .inherit, target: targetQueue)
        let processingQueue = targetQueue ?? DispatchQueue(label: Self.reverseDNS + ".processing", qos: qos, attributes: .concurrent, autoreleaseFrequency: .inherit, target: targetQueue)
        let channel = try Self.Channel(rootURL: rootURL, queue: priviledgeQueue)
        try self.init(rootURL: rootURL, channel: channel, queue: processingQueue)
    }
    
    /// Designated initializer for the database instance providing the database configuration.
    /// - parameter rootURL: The file URL where the databse file is or `nil` for "in memory" storage.
    /// - parameter channel: The SQLite opaque pointer to the database.
    /// - parameter queue: The queue on which to process the `DB` requests and responses.
    /// - throws: `IG.DB.Error` exclusively.
    internal init(rootURL: URL?, channel: IG.DB.Channel, queue: DispatchQueue) throws {
        self.rootURL = rootURL
        self.channel = channel
        self.queue = queue
        try self.migrateToLatestVersion()
    }
}

extension IG.DB {
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
        return IG.Bundle.identifier + ".db"
    }
}

extension IG.DB: DebugDescriptable {
    internal static var printableDomain: String {
        return "\(IG.Bundle.name).\(Self.self)"
    }
    
    public final var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("root URL", self.rootURL.map { $0.path } ?? ":memory:")
        result.append("queue", self.queue.label)
        result.append("queue QoS", String(describing: self.queue.qos.qosClass))
        result.append("version", IG.DB.Migration.Version.latest.rawValue)
        result.append("SQLite", SQLITE_VERSION)
        return result.generate()
    }
}
