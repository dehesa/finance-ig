import Conbini
import Combine
import Foundation
import SQLite3

extension Database {
    /// Database pipeline's first stage variables: the Database instance to use and some computed values (or `Void`).
    internal typealias Transit<T> = (database: Database, values: T)

    /// Publisher sending downstream the receiving `DB` instance. If the instance has been deallocated when the chain is activated a failure is sent downstream isntead.
    /// - returns: Publisher sending a `DB` instance and completing immediately once it is activated.
    internal var publisher: DeferredResult<Database.Transit<Void>,IG.Error> {
        DeferredResult { [weak self] in
            guard let self = self else { return .failure( IG.Error._deallocatedDB() ) }
            return .success( (self,()) )
        }
    }
    
    /// Publisher sending downstream the receiving `Database` instance and some computed values. If the instance has been deallocated or the values cannot be generated, the publisher fails.
    /// - parameter valuesGenerator: Closure generating the values to be send downstream along with the `Database` instance.
    /// - returns: Publisher sending a `Database` instance along with some computed values and completing immediately once it is activated.
    internal func publisher<T>(_ valuesGenerator: @escaping (_ db: Database) throws -> T) -> DeferredResult<Database.Transit<T>,IG.Error> {
        DeferredResult { [weak self] in
            guard let self = self else { return .failure( IG.Error._deallocatedDB() ) }
            do {
                let values = try valuesGenerator(self)
                return .success( (self, values) )
            } catch let error as IG.Error {
                return .failure( error )
            } catch let error {
                return .failure( IG.Error._invalidPrecomputedValues(error: error) )
            }
        }
    }
}

extension Publisher where Failure==IG.Error {
    /// Reads from the database received as an the receiving publisher `Output`.
    /// - parameter interaction: Closure having access to the priviledge database connection.
    ///  - parameter database: The SQLite low-level connection.
    ///  - parameter statement: Opaque SQLite statement pointer to be filled by the `interaction` closure.
    ///  - parameter values: Any value arriving as an output from upstream.
    /// - returns: Publisher outputting a single value and completing successfully, or failing.
    internal func read<T,R>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T) throws -> R) -> Publishers.FlatMap<DeferredFuture<R,Failure>,Self> where Output==Database.Transit<T> {
        return self
            .flatMap { (database, values) in
                DeferredFuture {
                    database.channel.readAsync(promise: $0, on: database.queue) { (sqlite) -> R in
                        var statement: SQLite.Statement? = nil
                        defer { sqlite3_finalize(statement) }
                        return try interaction(sqlite, &statement, values)
                    }
                }
            }
    }
    
    /// Reads from the database received as an the receiving publisher `Output`.
    ///
    /// The interaction closure exposes a way to check whether the operation has been cancelled midway.
    /// - parameter interaction: Closure having access to the priviledge database connection.
    ///  - parameter database: The SQLite low-level connection.
    ///  - parameter statement: Opaque SQLite statement pointer to be filled by the `interaction` closure.
    ///  - parameter values: Any value arriving as an output from upstream.
    ///  - parameter isCancelled: Closure called within the `interaction` to check whether the operation has been cancelled and there is no need to continue reading from the database.
    /// - returns: Publisher outputting a single value and completing successfully, or failing.
    internal func cancellableRead<T,R>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T, _ isCancelled: ()->Bool) throws -> R) -> Combine.Publishers.FlatMap<DeferredFuture<R,Failure>,Publishers.HandleEvents<Self>> where Output==Database.Transit<T> {
        var isCancelled: Bool = false
        return self
            .handleEvents(receiveCancel: { isCancelled = true })
            .flatMap { (database, values) in
                DeferredFuture { (promise) in
                    database.channel.readAsync(promise: promise, on: database.queue) { (sqlite) -> R in
                        var statement: SQLite.Statement? = nil
                        defer { sqlite3_finalize(statement) }
                        return try interaction(sqlite, &statement, values) { isCancelled }
                    }
                }
            }
    }

    /// Reads/Writes from the database.
    /// - parameter interaction: Closure having access to the priviledge database connection.
    ///  - parameter database: The SQLite low-level connection.
    ///  - parameter statement: Opaque SQLite statement pointer to be filled by the `interaction` closure.
    ///  - parameter values: Any value arriving as an output from upstream.
    /// - returns: Publisher forwarding a single value and completing successfully, or failing.
    internal func write<T,R>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T) throws -> R) -> Combine.Publishers.FlatMap<DeferredFuture<R,Failure>,Self> where Output==Database.Transit<T> {
        return self
            .flatMap { (database, values) in
                DeferredFuture {
                    database.channel.writeAsync(promise: $0, on: database.queue) { (sqlite) -> R in
                        var statement: SQLite.Statement? = nil
                        defer { sqlite3_finalize(statement) }
                        return try interaction(sqlite, &statement, values)
                    }
                }
            }
    }
    
    /// Reads/Writes from the database.
    ///
    /// The interaction closure exposes a way to check whether the operation has been cancelled midway.
    /// - parameter interaction: Closure having access to the priviledge database connection.
    ///  - parameter database: The SQLite low-level connection.
    ///  - parameter statement: Opaque SQLite statement pointer to be filled by the `interaction` closure.
    ///  - parameter values: Any value arriving as an output from upstream.
    ///  - parameter isCancelled: Closure called within the `interaction` to check whether the operation has been cancelled and there is no need to continue reading/writing from the database.
    /// - returns: Publisher forwarding a single value and completing successfully, or failing.
    internal func cancellableWrite<T,R>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T, _ isCancelled: ()->Bool) throws -> R) -> Combine.Publishers.FlatMap<DeferredFuture<R,Failure>,Publishers.HandleEvents<Self>> where Output==Database.Transit<T> {
        var isCancelled: Bool = false
        return self
            .handleEvents(receiveCancel: { isCancelled = true })
            .flatMap { (database, values) in
                DeferredFuture { (promise) in
                    database.channel.writeAsync(promise: promise, on: database.queue) { (sqlite) -> R in
                        var statement: SQLite.Statement? = nil
                        defer { sqlite3_finalize(statement) }
                        return try interaction(sqlite, &statement, values) { isCancelled }
                    }
                }
            }
    }
}

private extension IG.Error {
    /// Error raised when the DB instance is deallocated.
    static func _deallocatedDB() -> Self {
        Self(.database(.sessionExpired), "The DB instance has been deallocated.", help: "The DB functionality is asynchronous. Keep around the API instance while the request/response is being processed.")
    }
    /// Error raised when the precomputed request values cannot be generated.
    static func _invalidPrecomputedValues(error: Swift.Error) -> Self {
        Self(.database(.invalidRequest), "The precomputed request values couldn't be generated.", help: "Read the request documentation and be sure to follow all requirements.", underlying: error)
    }
}
