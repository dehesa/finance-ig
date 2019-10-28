import Conbini
import Combine
import Foundation
import SQLite3

extension IG.DB {
    
    /// List of custom publishers.
    public enum Publishers {
        /// Type erased `Combine.Future` where a single value and a completion or a failure will be sent.
        /// This behavior is guaranteed when you see this type.
        public typealias Discrete<T> = Combine.AnyPublisher<T,IG.DB.Error>
        /// Publisher that can send zero, one, or many values followed by a successful completion.
        public typealias Continuous<T> = Combine.AnyPublisher<T,IG.DB.Error>

        /// Publisher output types.
        internal enum Output {
            /// DB pipeline's first stage variables: the DB instance to use and some computed values (or `Void`).
            internal typealias Instance<T> = (database: IG.DB, values: T)
        }
    }
}

extension IG.DB {
    /// Publisher sending downstream the receiving `DB` instance. If the instance has been deallocated when the chain is activated a failure is sent downstream isntead.
    /// - returns: A Combine `Future` sending a `DB` instance and completing immediately once it is activated.
    internal var publisher: DeferredResult<IG.DB.Publishers.Output.Instance<Void>,IG.DB.Error> {
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
    internal func publisher<T>(_ valuesGenerator: @escaping (_ db: IG.DB) throws -> T) -> DeferredResult<IG.DB.Publishers.Output.Instance<T>,IG.DB.Error> {
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
    internal func read<T,R>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T) throws -> R) -> Combine.Publishers.FlatMap<Future<R,IG.DB.Error>,Self> where Self.Output==IG.DB.Publishers.Output.Instance<T>, Self.Failure==IG.DB.Error {
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
    
    /// Reads/Writes from the database received as an the receiving publisher `Output`.
    /// - parameter interaction: Closure having access to the priviledge database connection.
    /// - parameter database: The SQLite low-level connection.
    /// - parameter statement: Opaque SQLite statement pointer to be filled by the `interaction` closure.
    /// - parameter values: Any value arriving as an output from upstream.
    /// - returns: A `Future`-like publisher returning a single value and completing successfully, or failing. 
    internal func write<T,R>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T) throws -> R) -> Combine.Publishers.FlatMap<Future<R,IG.DB.Error>,Self> where Self.Output==IG.DB.Publishers.Output.Instance<T>, Self.Failure==IG.DB.Error {
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
}
