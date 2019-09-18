//import ReactiveSwift
//import Foundation
//import SQLite3
//
//// MARK: - Request types
//extension IG.DB.Request {
//    /// Request values that have been verified/validated.
//    internal typealias WrapperValid<T> = (database: IG.DB, values: T)
//    ///
//    internal typealias WrapperCompiled<T> = (database: IG.DB, statement: SQLite.Statement, values: T)
//
//    /// List of typealias representing closures which generate a specific data type.
//    internal enum Generator {
//        /// Closure returning some values that have been validated.
//        typealias Validation<T> = () throws -> T
//        /// Closure returning an SQL `String` statement.
//        typealias Compilation<T> = (_ values: T) throws -> String
//        /// Closure which will bind some variables to a SQLite statement.
//        typealias Binder<T> = (_ statement: SQLite.Statement, _ values: T) throws -> Void
//        ///
//        typealias Stepper<T,R> = (_ statement: SQLite.Statement, _ values: T, _ code: SQLite.Result) throws -> IG.DB.Response.Step<R>
//    }
//}
//
//// MARK: - Response types
//extension IG.DB.Response {
//    ///
//    internal enum Step<T> {
//        case next(T?)
//        case done(T?)
//    }
//}
//
//extension SignalProducer where Value==IG.DB.Request.WrapperValid<Void>, Error==IG.DB.Error {
//    /// Initializes a `SignalProducer` that checks (when started) whether the passed database session has expired.
//    /// - attention: This initializer creates a weak bond with the  database instance passed as argument. When the `SignalProducer` is started, the bond will be tested and if the instance is `nil`, the `SignalProducer` will generate an error event.
//    /// - parameter database: The database session where SQLite calls will be performed.
//    /// - Returns: The database instance and completes inmediately.
//    internal init(database: IG.DB) {
//        self.init { [weak database] (generator, _) in
//            guard let database = database else {
//                return generator.send(error: .sessionExpired())
//            }
//
//            generator.send(value: (database, ()))
//            generator.sendCompleted()
//        }
//    }
//
//    /// Compiles a SQL statement into binary format.
//    internal func compile(sql sqlGenerator: @escaping @autoclosure () -> String) -> SignalProducer<IG.DB.Request.WrapperCompiled<Void>,Self.Error> {
//        return self.compile(sqlGenerator)
//    }
//}
//
//extension SignalProducer where Error==IG.DB.Error {
//    /// Initializes a `SignalProducer` that checks (when started) whether the passed database session has expired.
//    /// - attention: This initializer creates a weak bond with the  database instance passed as argument. When the `SignalProducer` is started, the bond will be tested and if the instance is `nil`, the `SignalProducer` will generate an error event.
//    /// - parameter database: The database session where SQLite calls will be performed.
//    /// - parameter validating: Closure validating some values that will pass with the signal event to the following step.
//    internal init<T>(database: IG.DB, validating: @escaping IG.DB.Request.Generator.Validation<T>) where Value==IG.DB.Request.WrapperValid<T> {
//        self.init { [weak database] (generator, _) in
//            guard let database = database else {
//                return generator.send(error: .sessionExpired())
//            }
//
//            let values: T
//            do {
//                values = try validating()
//            } catch let error as Self.Error {
//                return generator.send(error: error)
//            } catch let underlyingError {
//                let error: Self.Error = .invalidRequest("The request validation failed", underlying: underlyingError, suggestion: .readDocs)
//                return generator.send(error: error)
//            }
//
//            generator.send(value: (database, values))
//            generator.sendCompleted()
//        }
//    }
//
//    /// Compiles a SQL statement into binary format.
//    internal func compile<T>(_ sqlGenerator: @escaping IG.DB.Request.Generator.Compilation<T>) -> SignalProducer<IG.DB.Request.WrapperCompiled<T>,Self.Error> where Value==IG.DB.Request.WrapperValid<T> {
//        return self.attemptMap { (database, validated) -> Result<IG.DB.Request.WrapperCompiled<T>,Self.Error> in
//            let sql: String
//            do {
//                sql = try sqlGenerator(validated)
//            } catch let error as Self.Error {
//                return .failure(error)
//            } catch let underlyingError {
//                return .failure(.invalidRequest(.compilingSQL, underlying: underlyingError, suggestion: .fileBug))
//            }
//
//            let result: Result<SQLite.Statement,Self.Error> = database.interact {
//                var statement: SQLite.Statement? = nil
//                if let compileError = sqlite3_prepare_v2($0, sql, -1, &statement, nil).enforce(.ok) {
//                    sqlite3_finalize(statement)
//                    var error: Self.Error = .callFailed(.compilingSQL, code: compileError)
//                    error.context.append(("SQL", sql))
//                    return .failure(error)
//                }
//                return .success(statement!)
//            }
//
//            return result.map { (database, $0, validated) }
//        }
//    }
//
//    ///
//    internal func bind<T>(_ binder: @escaping IG.DB.Request.Generator.Binder<T>) -> SignalProducer<Self.Value,Self.Error> where Value==IG.DB.Request.WrapperCompiled<T> {
//        return self.attemptMap { (database, statement, validated) -> Result<IG.DB.Request.WrapperCompiled<T>,Self.Error> in
//            let result: Result<(),Self.Error> = database.interact { _ in
//                do {
//                    return .success(try binder(statement, validated))
//                } catch let error as Self.Error {
//                    sqlite3_finalize(statement)
//                    return .failure(error)
//                } catch let underlyingError {
//                    sqlite3_finalize(statement)
//                    return .failure(.invalidRequest("An error occurred while binding values to a SQL statement", underlying: underlyingError, suggestion: .reviewError))
//                }
//            }
//            return result.map { (database, statement, validated) }
//        }
//    }
//
//    ///
//    internal func execute<T,R>(_ step: @escaping IG.DB.Request.Generator.Stepper<T,R>) -> SignalProducer<R,Self.Error> where Value==IG.DB.Request.WrapperCompiled<T> {
//        return self.remake { (input, generator, lifetime) in
//            do {
//                repeat {
//                    let todo = try input.database.interact { _ -> IG.DB.Response.Step<R> in
//                        let code = sqlite3_step(input.statement).result
//                        return try step(input.statement, input.values, code)
//                    }
//
//                    switch todo {
//                    case .next(let v?): generator.send(value: v); fallthrough
//                    case .next: break
//                    case .done(let v?): generator.send(value: v); fallthrough
//                    case .done:
//                        sqlite3_finalize(input.statement)
//                        return generator.sendCompleted()
//                    }
//                } while !lifetime.hasEnded
//                return generator.sendInterrupted()
//            } catch let error as IG.DB.Error {
//                sqlite3_finalize(input.statement)
//                return generator.send(error: error)
//            } catch let error {
//                sqlite3_finalize(input.statement)
//                return generator.send(error: .init(.callFailed, "Error occurred executing SQL step", suggestion: IG.DB.Error.Suggestion.reviewError.rawValue, underlying: error))
//            }
//        }
//    }
//}
