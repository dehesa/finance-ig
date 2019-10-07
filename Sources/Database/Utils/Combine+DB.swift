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

#warning("DB: Complete documentation")
extension Publisher {
    ///
    internal func read<T,R>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T) throws -> R) -> Publishers.TryMap<Self,R> where Self.Output==IG.DB.Output.Instance<T> {
        self.tryMap { (database, values) -> R in
            try database.channel.read { (sqlite) -> R in
                var statement: SQLite.Statement? = nil
                defer { sqlite3_finalize(statement) }
                
                return try interaction(sqlite, &statement, values)
            }
        }
    }
    
    ///
    internal func write<T>(_ interaction: @escaping (_ database: SQLite.Database, _ statement: inout SQLite.Statement?, _ values: T) throws -> Void) -> Publishers.FlatMap<DeferredCompletion<Void,IG.DB.Error>,Self> where Self.Output==IG.DB.Output.Instance<T> {
        self.flatMap { (database, values) -> DeferredCompletion<Void,IG.DB.Error> in
            let error: IG.DB.Error?
            do {
                try database.channel.write { (sqlite) in
                    var statement: SQLite.Statement? = nil
                    defer { sqlite3_finalize(statement) }
                    try interaction(sqlite, &statement, values)
                }
                error = nil
            } catch let e as IG.DB.Error {
                error = e
            } catch let e {
                error = IG.DB.Error.transform(e)
            }
            return .init(error: error)
        }
    }
}
