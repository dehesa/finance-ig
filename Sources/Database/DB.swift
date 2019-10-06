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
    
    /// It holds data and functionality related to the user's applications.
    public final var applications: IG.DB.Request.Applications { return .init(database: self) }
//    /// It holds data and functionality related to the user's activity & transactions, and market prices.
//    public final var history: IG.DB.Request.History { return .init(database: self) }
//    /// It holds data and functionality related to the platform's market.
//    public final var markets: IG.DB.Request.Markets { return .init(database: self) }
    #warning("DB: Uncomment")
    
    /// Creates a database instance fetching and storing values from/to the given location.
    /// - parameter rootURL: The file location or `nil` for "in memory" storage.
    /// - parameter targetQueue: The target queue on which to process the `DB` requests and responses.
    /// - throws: `IG.DB.Error` exclusively.
    public convenience init(rootURL: URL?, targetQueue: DispatchQueue?) throws {
        let priviledgeQueue = DispatchQueue(label: Self.reverseDNS + ".channel", qos: .utility, autoreleaseFrequency: .never, target: targetQueue)
        let processingQueue = DispatchQueue(label: Self.reverseDNS + ".values",  qos: .utility, autoreleaseFrequency: .never, target: targetQueue)
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
    
//    /// Performs a work item on the database priviledge queue.
//    /// - precondition: The caller must not be on the priviledge database dispatch queue or this function will crash.
//    /// - parameter interaction: Closure giving the priviledge database connection and a way to check whether the operation should be finished (since database operations may extend for a long time). Its result will be forwarded to the Signal.
//    /// - parameter channel: The priviledge SQLite database actually performing the work.
//    /// - parameter permission: A closure to ask for *continuation* permission to the database manager.
//    internal final func work<R>(_ interaction: @escaping (_ channel: SQLite.Database, _ permission: IG.DB.Request.Permission) -> IG.DB.Response.Step<R>) -> SignalProducer<R,IG.DB.Error> {
//        dispatchPrecondition(condition: .notOnQueue(self.queue))
//
//        return SignalProducer<R,IG.DB.Error> { [weak self] (generator, lifetime) in
//            var result: IG.DB.Response.Step<R> = .expired
//            var permission: IG.DB.Request.Step = .continue
//            var detacher = lifetime.observeEnded { permission = .stop }
//
//            self?.queue.sync { [shallContinue = { permission }] in
//                guard let self = self else { return }
//                result = interaction(self.channel, shallContinue)
//            }
//
//            detacher?.dispose()
//            detacher = nil
//
//            switch result {
//            case .success(value: let value):
//                generator.send(value: value)
//                generator.sendCompleted()
//            case .failure(error: let error):
//                generator.send(error: error)
//            case .expired:
//                generator.send(error: .sessionExpired())
//            case .interruption:
//                generator.sendInterrupted()
//            }
//        }
//    }
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
