import Combine
import Foundation
import SQLite3

extension IG.DB {
    /// Publisher sending downstream the receiving `DB` instance. If the instance has been deallocated when the chain is activated a failure is sent downstream isntead.
    /// - returns: A Combine `Future` sending a `DB` instance and completing immediately once it is activated.
    internal var publisher: DeferredResult<IG.DB.Output.Instance<Void>,IG.DB.Error> {
        .init { [weak self] in
            if let self = self {
                return .success( (self,()) )
            } else {
                return .failure(.sessionExpired())
            }
        }
    }
    
    /// Publisher sending downstream the receiving `DB` instance and some computed values. If the instance has been deallocated or the values cannot be generated, the publisher fails.
    /// - parameter valuesGenerator: Closure generating the values to be send downstream along with the `DB` instance.
    /// - returns: A Combine `Future` sending a `DB` instance along with some computed values and completing immediately once it is activated.
    internal func publisher<T>(_ valuesGenerator: @escaping (_ db: IG.DB) throws -> T) -> DeferredResult<IG.DB.Output.Instance<T>,IG.DB.Error> {
        .init { [weak self] in
            guard let self = self else { return .failure(.sessionExpired()) }
            do {
                let values = try valuesGenerator(self)
                return .success( (self, values) )
            } catch let error as IG.DB.Error {
                return .failure(error)
            } catch let underlyingError {
                return .failure(.invalidRequest("The precomputed values couldn't be generated", underlying: underlyingError, suggestion: .readDocs))
            }
        }
    }
}

extension Publisher {
    /// Reads from the database received as an the receiving publisher `Output`.
    /// - parameter interaction: Closure having access to the priviledge database connection.
    /// - parameter database: The SQLite low-level connection.
    /// - parameter statement: Opaque SQLite statement pointer to be filled by the `interaction` closure.
    /// - parameter values: Any value arriving as an output from upstream.
    /// - returns: A `Future`-like publisher returning a single value and completing successfully, or failing.
    internal func read<T,R>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T) throws -> R) -> Publishers.FlatMap<Future<R,IG.DB.Error>,Self> where Self.Output==IG.DB.Output.Instance<T>, Self.Failure==IG.DB.Error {
        self.flatMap { (database, values) in
            .init { (promise) in
                database.channel.readAsync(promise: promise, on: database.queue) { (sqlite) in
                    var statement: SQLite.Statement? = nil
                    defer { sqlite3_finalize(statement) }
                    return try interaction(sqlite, &statement, values)
                }
            }
        }
    }
    
//    internal func readContinuously<T,R>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T, _ sender: (R)->Void) throws -> Void) -> AnyPublisher<R,IG.DB.Error> where Self.Output==IG.DB.Output.Instance<T> {
//
//    }
    
    /// Reads/Writes from the database received as an the receiving publisher `Output`.
    /// - parameter interaction: Closure having access to the priviledge database connection.
    /// - parameter database: The SQLite low-level connection.
    /// - parameter statement: Opaque SQLite statement pointer to be filled by the `interaction` closure.
    /// - parameter values: Any value arriving as an output from upstream.
    /// - returns: A `Future`-like publisher returning a single value and completing successfully, or failing. 
    internal func write<T,R>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T) throws -> R) -> Publishers.FlatMap<Future<R,IG.DB.Error>,Self> where Self.Output==IG.DB.Output.Instance<T>, Self.Failure==IG.DB.Error {
        self.flatMap { (database, values) in
            .init { (promise) in
                database.channel.writeAsync(promise: promise, on: database.queue) { (sqlite) in
                    var statement: SQLite.Statement? = nil
                    defer { sqlite3_finalize(statement) }
                    return try interaction(sqlite, &statement, values)
                }
            }
        }
    }
    
//    internal func writeContinuously<T,R>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T, _ sender: (R)->Void) throws -> Void) -> AnyPublisher<R,IG.DB.Error> where Self.Output==IG.DB.Output.Instance<T> {
//
//    }
}
