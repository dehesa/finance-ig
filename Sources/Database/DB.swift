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
    /// It holds data and functionality related to the platform's market.
    public var markets: IG.DB.Request.Markets { return .init(database: self) }
    
    /// Creates a database instance fetching and storing values from/to the given location.
    /// - parameter rootURL: The file location or `nil` for "in memory" storage.
    /// - parameter targetQueue: The target queue on which to process the `DB` requests and responses.
    /// - throws: `IG.DB.Error` exclusively.
    public convenience init(rootURL: URL?, targetQueue: DispatchQueue?) throws {
        let queue = DispatchQueue(label: Self.reverseDNS,   qos: .utility, autoreleaseFrequency: .never, target: targetQueue)
        let channel = try Self.Channel.make(rootURL: rootURL, on: queue)
        try self.init(rootURL: rootURL, channel: channel, queue: queue)
    }
    
    /// Designated initializer for the database instance providing the database configuration.
    /// - parameter rootURL: The file URL where the databse file is or `nil` for "in memory" storage.
    /// - parameter queue: The queue on which to process the `DB` requests and responses.
    /// - throws: `IG.DB.Error` exclusively.
    internal init(rootURL: URL?, channel: SQLite.Database, queue: DispatchQueue) throws {
        self.rootURL = rootURL
        self.channel = channel
        self.queue = queue
        
        try IG.DB.Migration.apply(for: channel, on: queue)
    }
    
    deinit {
        Self.Channel.destroy(channel: self.channel, on: self.queue)
    }
    
    /// Performs a work item on the database priviledge queue.
    /// - precondition: The caller must not be on the priviledge database dispatch queue or this function will crash.
    /// - parameter interaction: Closure giving the priviledge database connection and a way to check whether the operation should be finished (since databse operations may extend for a long time). Its result will be forwarded to the Signal.
    /// - parameter channel: The priviledge SQLite database actually performing the work.
    /// - parameter permission: A closure to ask for *continuation* permission to the database manager.
    internal func work<R>(_ interaction: @escaping (_ channel: SQLite.Database, _ permission: IG.DB.Request.Permission) -> IG.DB.Response.Step<R>) -> SignalProducer<R,IG.DB.Error> {
        dispatchPrecondition(condition: .notOnQueue(self.queue))
        
        return SignalProducer<R,IG.DB.Error> { [weak self] (generator, lifetime) in
            var result: IG.DB.Response.Step<R> = .expired
            var permission: IG.DB.Request.Step = .continue
            var detacher = lifetime.observeEnded { permission = .stop }
            
            self?.queue.sync { [shallContinue = { permission }] in
                guard let self = self else { return }
                result = interaction(self.channel, shallContinue)
            }
            
            detacher?.dispose()
            detacher = nil
            
            switch result {
            case .success(value: let value):
                generator.send(value: value)
                generator.sendCompleted()
            case .failure(error: let error):
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
        return "IG.\(Self.self)"
    }
    
    public var debugDescription: String {
        var result = IG.DebugDescription(Self.printableDomain)
        result.append("root URL", self.rootURL.map { $0.path } ?? ":memory:")
        result.append("queue", self.queue.label)
        result.append("queue QoS", String(describing: self.queue.qos.qosClass))
        result.append("version", IG.DB.Migration.Version.latest.rawValue)
        result.append("SQLite", SQLITE_VERSION)
        return result.generate()
    }
}
