import ReactiveSwift
import Foundation
import SQLite3

/// The Database instance is the bridge between the internal SQLite storage
public final class DB {
    /// File URL where the database is found.
    ///
    /// If `nil` the database is created "in memory".
    public let rootURL: URL?
    /// The underlying instance (whether real or mocked) actually storing/reading the information.
    ///
    /// The access is restricted by the database queue. Only access this pointer from there.
    private let channel: SQLite.Database
    /// The queue restricting database entry.
    private let queue: DispatchQueue
    
    /// It holds data and functionality related to the user's applications.
    public var applications: IG.DB.Request.Applications { return .init(database: self) }
    
    /// Creates a database instance fetching and storing values from/to the given location.
    /// - parameter rootURL: The file location or `nil` for "in memory" storage.
    /// - parameter targetQueue: The target queue on which to process the `DB` requests and responses.
    /// - throws: `IG.DB.Error` exclusively.
    public convenience init(rootURL: URL?, targetQueue: DispatchQueue?) throws {
        let queue = DispatchQueue(label: Self.reverseDNS + ".sqlite",   qos: .utility, autoreleaseFrequency: .never, target: targetQueue)
        let channel = try Self.Channel.make(rootURL: rootURL, on: queue)
        try self.init(rootURL: rootURL, channel: channel, queue: queue)
    }
    
    /// Designated initializer for the database instance providing the database configuration.
    /// - parameter rootURL: The file URL where the databse file is or `nil` for "in memory" storage.
    /// - parameter queue: The queue on which to process the `DB` requests and responses.
    /// - throws: `IG.DB.Error` exclusively.
    internal init(rootURL: URL?, channel: SQLite.Database, queue: DispatchQueue, migrating version: IG.DB.Migration.Version = .latest) throws {
        self.rootURL = rootURL
        self.channel = channel
        self.queue = queue
        
        try IG.DB.Migration.apply(untilVersion: version, for: channel, on: queue)
    }
    
    deinit {
        Self.Channel.destroy(channel: self.channel, on: self.queue)
    }
    
    /// Performs a work on the database priviledge queue
    internal func work<R>(_ interaction: @escaping (_ channel: SQLite.Database, _ permission: IG.DB.Request.Expiration) -> IG.DB.Response<R>) -> SignalProducer<R,IG.DB.Error> {
        dispatchPrecondition(condition: .notOnQueue(self.queue))
        return SignalProducer<R,IG.DB.Error>.init { [weak self] (generator, lifetime) in
            var result: IG.DB.Response<R> = .expired
            var permission: IG.DB.Request.Iteration = .continue
            var detacher = lifetime.observeEnded { permission = .stop }
            
            self?.queue.sync { [shallContinue = { permission }] in
                guard let self = self else { return }
                result = interaction(self.channel, shallContinue)
            }
            
            detacher?.dispose()
            detacher = nil
            
            switch result {
            case .success(let value):
                generator.send(value: value)
                generator.sendCompleted()
            case .failure(let error):
                generator.send(error: error)
            case .expired:
                generator.send(error: .sessionExpired())
            case .interruption:
                generator.sendInterrupted()
            }
        }
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

extension IG.DB: DebugDescriptable {
    static var printableDomain: String {
        return "IG.\(IG.DB.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("Root URL", self.rootURL.map { $0.path } ?? ":memory:")
        result.append("SQLite version", SQLITE_VERSION)
        result.append("Database queue", self.queue.label)
        result.append("Database queue QoS", String(describing: self.queue.qos.qosClass))
        return result.generate()
    }
}
