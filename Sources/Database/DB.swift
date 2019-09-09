import Foundation
import SQLite3

/// The Database instance is the bridge between the internal SQLite storage
public final class DB {
    /// File URL where the database is found.
    ///
    /// If `nil` the database is created "in memory".
    public let rootURL: URL?
    /// The queues processing all API requests and responses.
    internal let queue: IG.DB.Queues
    /// The underlying instance (whether real or mocked) actually storing/reading the information.
    ///
    /// The access is restricted by the database queue. Only access this pointer from there.
    internal let channel: OpaquePointer
    #warning("Make the channel private")
    
    /// It holds data and functionality related to the user's applications.
    public var applications: IG.DB.Request.Applications { return .init(database: self) }
    
    /// Creates a database instance fetching and storing values from/to the given location.
    /// - parameter rootURL: The file location or `nil` for "in memory" storage.
    /// - parameter targetQueue: The target queue on which to process the `DB` requests and responses.
    /// - throws: `IG.Database.Error`
    public convenience init(rootURL: URL?, targetQueue: DispatchQueue?) throws {
        let queues: IG.DB.Queues = (
            DispatchQueue(label: Self.reverseDNS + ".sqlite", qos: .utility, autoreleaseFrequency: .never, target: targetQueue),
            DispatchQueue(label: Self.reverseDNS + ".response", qos: .utility, autoreleaseFrequency: .never, target: targetQueue)
        )
        let channel = try Self.Channel.make(rootURL: rootURL, on: queues.database)
        self.init(rootURL: rootURL, channel: channel, queues: queues)
    }
    
    /// Designated initializer for the database instance providing the database configuration.
    /// - parameter rootURL: The file URL where the databse file is or `nil` for "in memory" storage.
    /// - parameter queue: The queue on which to process the `DB` requests and responses.
    /// - throws: `IG.Database.Error`
    internal init(rootURL: URL?, channel: OpaquePointer, queues: IG.DB.Queues) {
        self.rootURL = rootURL
        self.queue = queues
        self.channel = channel
    }
    
    deinit {
        Self.Channel.destroy(channel: self.channel, on: self.queue.database)
    }
}

extension IG.DB {
    /// Tuple identifying the different types of queues.
    typealias Queues = (database: DispatchQueue, response: DispatchQueue)
    
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
        return IG.bundleIdentifier() + ".db"
    }
}

extension IG.DB: DebugDescriptable {
    static var printableDomain: String {
        return "IG.\(IG.DB.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("Root URL", self.rootURL.map { $0.path } ?? ":memory:")
        result.append("SQLite version", SQLITE_VERSION)
        result.append("Database queue", self.queue.database.label)
        result.append("Database queue QoS", String(describing: self.queue.database.qos.qosClass))
        result.append("Response queue", self.queue.response.label)
        result.append("Response queue QoS", String(describing: self.queue.response.qos.qosClass))
        return result.generate()
    }
}
