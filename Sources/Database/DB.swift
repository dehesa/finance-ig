import Foundation

/// The Database instance is the bridge between the internal SQLite storage
public final class DB {
    /// File URL where the database is found.
    ///
    /// If `nil` the database is created "in memory".
    public let rootURL: URL?
    /// The queue processing all API requests and responses.
    private let queue: DispatchQueue
    /// The underlying instance (whether real or mocked) actually storing/reading the information.
    private let channel: OpaquePointer
    
    /// It holds data and functionality related to the user's applications.
    public var applications: IG.DB.Request.Applications { return .init(database: self) }
    
    /// Creates a database instance fetching and storing values from/to the given location.
    /// - parameter rootURL: The file location or `nil` for "in memory" storage.
    /// - parameter targetQueue: The target queue on which to process the `DB` requests and responses.
    /// - throws: `IG.Database.Error`
    public convenience init(rootURL: URL?, targetQueue: DispatchQueue?) throws {
        let queue = DispatchQueue(label: Self.reverseDNS, qos: .utility, autoreleaseFrequency: .never, target: targetQueue)
        let channel = try Self.Channel.make(rootURL: rootURL, on: queue)
        self.init(rootURL: rootURL, channel: channel, queue: queue)
    }
    
    /// Designated initializer for the database instance providing the database configuration.
    /// - parameter rootURL: The file URL where the databse file is or `nil` for "in memory" storage.
    /// - parameter queue: The queue on which to process the `DB` requests and responses.
    /// - throws: `IG.Database.Error`
    internal init(rootURL: URL?, channel: OpaquePointer, queue: DispatchQueue) {
        self.rootURL = rootURL
        self.queue = queue
        self.channel = channel
    }
    
    deinit {
        Self.Channel.destroy(channel: self.channel, on: self.queue)
    }
    
    internal func work<T>(_ item: (_ channel: OpaquePointer)->T) -> T {
        fatalError()
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
        return IG.bundleIdentifier() + ".db"
    }
}
