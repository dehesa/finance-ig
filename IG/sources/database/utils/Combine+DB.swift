import Conbini
import Combine
import Foundation
import SQLite3

extension IG.Database {
    /// Publisher output types.
    internal enum Transit {
        /// Database pipeline's first stage variables: the Database instance to use and some computed values (or `Void`).
        typealias Instance<T> = (database: IG.Database, values: T)
    }
}

extension IG.Database {
    /// Publisher sending downstream the receiving `DB` instance. If the instance has been deallocated when the chain is activated a failure is sent downstream isntead.
    /// - returns: A Combine `Future` sending a `DB` instance and completing immediately once it is activated.
    internal var publisher: DeferredResult<IG.Database.Transit.Instance<Void>,IG.Database.Error> {
        .init { [weak self] in
            if let self = self {
                return .success( (self,()) )
            } else {
                return .failure(.sessionExpired())
            }
        }
    }
    
    /// Publisher sending downstream the receiving `Database` instance and some computed values. If the instance has been deallocated or the values cannot be generated, the publisher fails.
    /// - parameter valuesGenerator: Closure generating the values to be send downstream along with the `Database` instance.
    /// - returns: A Combine `Future` sending a `Database` instance along with some computed values and completing immediately once it is activated.
    internal func publisher<T>(_ valuesGenerator: @escaping (_ db: IG.Database) throws -> T) -> DeferredResult<IG.Database.Transit.Instance<T>,IG.Database.Error> {
        .init { [weak self] in
            guard let self = self else { return .failure(.sessionExpired()) }
            do {
                let values = try valuesGenerator(self)
                return .success( (self, values) )
            } catch let error as IG.Database.Error {
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
    internal func read<T,R>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T, _ isCancelled: ()->Bool) throws -> R) -> Combine.Publishers.AsyncTryMap<Self,R> where Output==IG.Database.Transit.Instance<T> {
        self.asyncTryMap(parallel: .max(1)) { (input, isCancelled, promise) in
            let mapper: (Result<R,IG.Database.Error>)->Void = { (result) in
                switch result {
                case .success(let value): _ = promise(.success((value, .finished)))
                case .failure(let error): _ = promise(.failure(error))
                }
            }
            
            input.database.channel.readAsync(promise: mapper, on: input.database.queue) { (sqlite) in
                var statement: SQLite.Statement? = nil
                defer { sqlite3_finalize(statement) }
                return try interaction(sqlite, &statement, input.values, isCancelled)
            }
        }
    }
    
    /// Reads/Writes from the database.
    /// - parameter interaction: Closure having access to the priviledge database connection.
    /// - parameter database: The SQLite low-level connection.
    /// - parameter statement: Opaque SQLite statement pointer to be filled by the `interaction` closure.
    /// - parameter values: Any value arriving as an output from upstream.
    /// - parameter isCancelled: Closure indicating whether the database request has been cancelled.
    /// - returns: A `Future`-like publisher returning a single value and completing successfully, or failing.
    internal func write<T,R>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T, _ isCancelled: ()->Bool) throws -> R) -> Combine.Publishers.AsyncTryMap<Self,R> where Output==IG.Database.Transit.Instance<T> {
        self.asyncTryMap(parallel: .max(1)) { (input, isCancelled, promise) in
            let mapper: (Result<R,IG.Database.Error>)->Void = { (result) in
                switch result {
                case .success(let value): _ = promise(.success((value, .finished)))
                case .failure(let error): _ = promise(.failure(error))
                }
            }
            
            input.database.channel.writeAsync(promise: mapper, on: input.database.queue) { (sqlite) -> R in
                var statement: SQLite.Statement? = nil
                defer { sqlite3_finalize(statement) }
                return try interaction(sqlite, &statement, input.values, isCancelled)
            }
        }
    }
}
