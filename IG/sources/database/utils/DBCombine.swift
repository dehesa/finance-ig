import Conbini
import Combine
import Foundation
import SQLite3

extension Database {
    /// Publisher output types.
    internal enum Transit {
        /// Database pipeline's first stage variables: the Database instance to use and some computed values (or `Void`).
        typealias Instance<T> = (database: Database, values: T)
    }
}

extension Database {
    /// Publisher sending downstream the receiving `DB` instance. If the instance has been deallocated when the chain is activated a failure is sent downstream isntead.
    /// - returns: Publisher sending a `DB` instance and completing immediately once it is activated.
    internal var publisher: DeferredResult<Database.Transit.Instance<Void>,IG.Error> {
        DeferredResult { [weak self] in
            guard let self = self else { return .failure( IG.Error(.database(.sessionExpired), "The DB instance has been deallocated.", help: "The DB functionality is asynchronous. Keep around the DB instance while request are being processed.") ) }
            return .success( (self,()) )
        }
    }
    
    /// Publisher sending downstream the receiving `Database` instance and some computed values. If the instance has been deallocated or the values cannot be generated, the publisher fails.
    /// - parameter valuesGenerator: Closure generating the values to be send downstream along with the `Database` instance.
    /// - returns: Publisher sending a `Database` instance along with some computed values and completing immediately once it is activated.
    internal func publisher<T>(_ valuesGenerator: @escaping (_ db: Database) throws -> T) -> DeferredResult<Database.Transit.Instance<T>,IG.Error> {
        DeferredResult { [weak self] in
            guard let self = self else { return .failure( IG.Error(.database(.sessionExpired), "The DB instance has been deallocated.", help: "The DB functionality is asynchronous. Keep around the DB instance while request are being processed.") ) }
            do {
                let values = try valuesGenerator(self)
                return .success( (self, values) )
            } catch let error as IG.Error {
                return .failure( error )
            } catch let underlyingError {
                return .failure( IG.Error(.database(.invalidRequest), "The precomputed values couldn't be generated.", help: "Read the request documentation and be sure to follow all requirements.", underlying: underlyingError) )
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
    /// - returns: Publisher outputting a single value and completing successfully, or failing.
    internal func read<T,R>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T, _ isCancelled: ()->Bool) throws -> R) -> Combine.Publishers.AsyncTryMap<Self,R> where Output==Database.Transit.Instance<T> {
        self.asyncTryMap(parallel: .max(1)) { (input, isCancelled, promise) in
            let mapper: (Result<R,IG.Error>) -> Void = {
                switch $0 {
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
    /// - returns: Publisher forwarding a single value and completing successfully, or failing.
    internal func write<T,R>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T, _ isCancelled: ()->Bool) throws -> R) -> Combine.Publishers.AsyncTryMap<Self,R> where Output==Database.Transit.Instance<T> {
        self.asyncTryMap(parallel: .max(1)) { (input, isCancelled, promise) in
            let mapper: (Result<R,IG.Error>) -> Void = {
                switch $0 {
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
