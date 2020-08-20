import Foundation
import SQLite3

internal extension Database {
    /// Contains the low-level functionality related to the SQLite database.
    final class Channel {
        /// Serial queue handling all database accesses.
        private let _queue: DispatchQueue
        /// The underlying SQLite instance (referencing the SQLite file).
        private let _database: SQLite.Database
        /// File URL where the database can be found.
        ///
        /// If `nil`, the database is created "in-memory".
        let rootURL: URL?
        
        /// Designated initializer creating/opening the SQLite database indicated by the `rootURL`.
        /// - parameter location: The location of the database (whether "in-memory" or file system).
        /// - parameter targetQueue: The target queue on which the database serializer will depend on.
        init(location: Database.Location, targetQueue: DispatchQueue?) throws {
            // Research: attributes: .concurrent
            self._queue = DispatchQueue(label: Bundle.IG.identifier + ".database.queue.channel", qos: .default, autoreleaseFrequency: .inherit, target: targetQueue)
            (self.rootURL, self._database) = try Self._make(location: location, queue: _queue)
        }
        
        deinit {
            Self._destroy(database: self._database, queue: self._queue)
        }
    }
}

extension Database.Channel {
    /// Reads and/or writes from the database directly (without any transaction).
    ///
    /// This is a barrier access, meaning that all other access are kept on hold while this interaction is in operation.
    /// - warning: Don't call another read or write within the `interaction` closure or a deadlock will occur.
    /// - parameter interaction: Closure giving the priviledge database connection.
    /// - parameter database: Low-level pointer to the SQLite database. Usage of this pointer outside the `interaction` closure produces a fatal error.
    /// - throws: Any error thrown by the `interaction` closure.
    /// - returns: The result returned in the `interaction` closure.
    func unrestrictedAccess<T>(_ interaction: (_ database: SQLite.Database) throws -> T) rethrows -> T {
        dispatchPrecondition(condition: .notOnQueue(self._queue))
        return try self._queue.sync(flags: .barrier) {
            try interaction(self._database)
        }
    }
    
    /// Reads from the database in a transaction.
    ///
    /// This is a parallel access, meaning that other read access may be performed in parallel.
    /// - warning: Don't call another read or write within the `interaction` closure or a deadlock will occur.
    /// - parameter interaction: Closure giving the priviledge database connection.
    /// - parameter database: Low-level pointer to the SQLite database. Usage of this pointer outside the `interaction` closure produces a fatal error.
    /// - throws: Any error thrown by the `interaction` closure.
    /// - returns: The result returned in the `interaction` closure.
    /// - todo: Make parallel reads (currently they are serial).
    func read<T>(_ interaction: (_ database: SQLite.Database) throws -> T) rethrows -> T {
        dispatchPrecondition(condition: .notOnQueue(self._queue))
        return try self._transactionAccess(flags: [], interaction)
    }
    
    /// Reads and/or writes from the database in a transaction.
    ///
    /// This is a barrier access, meaning that all other access are kept on hold while this interaction is in operation.
    /// - warning: Don't call another read or write within the `interaction` closure or a deadlock will occur.
    /// - parameter interaction: Closure giving the priviledge database connection.
    /// - parameter database: Low-level pointer to the SQLite database. Usage of this pointer outside the `interaction` closure produces a fatal error.
    /// - throws: Any error thrown by the `interaction` closure.
    /// - returns: The result returned in the `interaction` closure.
    func write<T>(_ interaction: (_ database: SQLite.Database) throws -> T) rethrows -> T {
        dispatchPrecondition(condition: .notOnQueue(self._queue))
        return try self._transactionAccess(flags: .barrier, interaction)
    }
    
    /// Reads and/or writes from the database in a transaction.
    ///
    /// This is a barrier access, meaning that all other access are kept on hold while this interaction is in operation.
    /// - warning: Don't call another read or write within the `interaction` closure or a deadlock will occur.
    /// - parameter interaction: Closure giving the priviledge database connection.
    /// - parameter database: Low-level pointer to the SQLite database. Usage of this pointer outside the `interaction` closure produces a fatal error.
    /// - throws: Any error thrown by the `interaction` closure.
    /// - returns: The result returned in the `interaction` closure.
    private func _transactionAccess<T>(flags: DispatchWorkItemFlags, _ interaction: (_ database: SQLite.Database) throws -> T) rethrows -> T {
        try self._queue.sync(flags: flags) {
            try sqlite3_exec(self._database, "BEGIN TRANSACTION", nil, nil, nil).expects(.ok)
            
            let output: T
            do {
                output = try interaction(self._database)
            } catch let error {
                if let errorCode = sqlite3_exec(self._database, "ROLLBACK", nil, nil, nil).enforce(.ok) {
                    fatalError("An error occurred (code: \(errorCode) trying to rollback an operation")
                }
                throw error
            }
            
            if let errorCode = sqlite3_exec(self._database, "END TRANSACTION", nil, nil, nil).enforce(.ok) {
                fatalError("An error occurred (code: \(errorCode) trying to end a transaction")
            }
            return output
        }
    }
}

extension Database.Channel {
    /// Reads from the database in a transaction that is executed asynchronously.
    ///
    /// This is a parallel access, meaning that other read access may be performed in parallel.
    /// - warning: Don't call another read or write within the `interaction` closure or a deadlock will occur.
    /// - parameter promise: Closure receiving the result of the transaction (that one returned by the `interaction` closure).
    /// - parameter receptionQueue: The queue where the `promise` will be executed.
    /// - parameter interaction: Closure giving the priviledge database connection.
    /// - parameter database: Low-level pointer to the SQLite database. Usage of this pointer outside the `interaction` closure produces a fatal error.
    func readAsync<T>(promise: @escaping (Result<T,IG.Error>) -> Void, on receptionQueue: DispatchQueue, _ interaction: @escaping (_ database: SQLite.Database) throws -> T) {
        dispatchPrecondition(condition: .notOnQueue(self._queue))
        self._asyncTransactionAccess(flags: [], promise: promise, on: receptionQueue, interaction)
    }
    
    /// Reads and/or writes from the database in a transaction.
    ///
    /// This is a barrier access, meaning that all other access are kept on hold while this interaction is in operation.
    /// - warning: Don't call another read or write within the `interaction` closure or a deadlock will occur.
    /// - parameter promise: Closure receiving the result of the transaction (that one returned by the `interaction` closure).
    /// - parameter receptionQueue: The queue where the `promise` will be executed.
    /// - parameter interaction: Closure giving the priviledge database connection.
    /// - parameter database: Low-level pointer to the SQLite database. Usage of this pointer outside the `interaction` closure produces a fatal error.
    func writeAsync<T>(promise: @escaping (Result<T,IG.Error>) -> Void, on receptionQueue: DispatchQueue, _ interaction: @escaping (_ database: SQLite.Database) throws -> T) {
        dispatchPrecondition(condition: .notOnQueue(self._queue))
        self._asyncTransactionAccess(flags: .barrier, promise: promise, on: receptionQueue, interaction)
    }
    
    /// Reads and/or writes from the database in a transaction.
    ///
    /// This is a barrier access, meaning that all other access are kept on hold while this interaction is in operation.
    /// - warning: Don't call another read or write within the `interaction` closure or a deadlock will occur.
    /// - parameter promise: Closure receiving the result of the transaction (that one returned by the `interaction` closure).
    /// - parameter receptionQueue: The queue where the `promise` will be executed.
    /// - parameter interaction: Closure giving the priviledge database connection.
    /// - parameter database: Low-level pointer to the SQLite database. Usage of this pointer outside the `interaction` closure produces a fatal error.
    private func _asyncTransactionAccess<T>(flags: DispatchWorkItemFlags, promise: @escaping (Result<T,IG.Error>) -> Void, on receptionQueue: DispatchQueue, _ interaction: @escaping (_ database: SQLite.Database) throws -> T) {
        self._queue.async(flags: flags) {
            if let errorCode = sqlite3_exec(self._database, "BEGIN TRANSACTION", nil, nil, nil).enforce(.ok) {
                return receptionQueue.async { promise(.failure(._invalidExecution(code: errorCode))) }
            }
            
            let output: T
            do {
                output = try interaction(self._database)
            } catch let error {
                if let errorCode = sqlite3_exec(self._database, "ROLLBACK", nil, nil, nil).enforce(.ok) {
                    fatalError("An error occurred (code: \(errorCode) trying to rollback an operation.")
                }
                
                switch error {
                case let e as IG.Error: return promise(.failure(e))
                case let e: return promise(.failure( IG.Error._invalidExecution(error: e) ))
                }
            }
            
            if let errorCode = sqlite3_exec(self._database, "END TRANSACTION", nil, nil, nil).enforce(.ok) {
                fatalError("An error occurred (code: \(errorCode) trying to end a transaction.")
            }
            
            return receptionQueue.async {
                promise(.success(output))
            }
        }
    }
}

private extension Database.Channel {
    /// Opens or creates a SQLite database and returns the pointer handler to it.
    /// - warning: This function will perform a `queue.sync()` operation. Be sure no deadlocks occurs.
    /// - parameter location: The location of the database (whether "in-memory" or file system).
    /// - parameter queue: The queue serializing access to the database.
    /// - throws: `IG.Error` exclusively.
    static func _make(location: Database.Location, queue: DispatchQueue) throws -> (rootURL: URL?, database: SQLite.Database) {
        let (rootURL, path): (URL?, String)
        
        // 1. Define file path (or in-memory keyword)
        switch location {
        case .memory:
            (rootURL, path) = (nil, ":memory:")
        case .file(let url, let expectsExistance):
            (rootURL, path) = (url, url.path)
            // Check the URL validity.
            guard url.isFileURL else { throw IG.Error._invalid(url: url) }
            
            switch expectsExistance {
            case .some(true):
                guard FileManager.default.fileExists(atPath: path) else {
                    throw IG.Error._unfoundDatabase(path: path)
                }
            case .some(false):
                guard !FileManager.default.fileExists(atPath: path) else {
                    throw IG.Error._conflictingFile(path: path)
                }
                fallthrough
            case .none:
                // Check the path to the file exists and if not create any intermediate path.
                if !FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path, isDirectory: nil) {
                    do {
                        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                    } catch let error {
                        throw IG.Error._invalidPath(error: error)
                    }
                }
            }
        }
        
        // 2. Open/Create the database connection
        var db: SQLite.Database? = nil
        var error: IG.Error? = queue.sync {
            let openFlags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX  /* SQLITE_OPEN_FULLMUTEX */
            guard let errorCode = sqlite3_open_v2(path, &db, openFlags, nil).enforce(.ok) else { return nil }
            
            let error = IG.Error._cannotOpenDB(code: errorCode)
            if let channel = db {
                let message = String(cString: sqlite3_errmsg(channel))
                if message != errorCode.description { error.errorUserInfo["Open error message"] = message }
            }
            return error
        }
        
        // If there is an error, it shall be thrown in the calling queue
        switch (db, error) {
        case (.some, .none): break
        case (let c?, let e?): Self._destroy(database: c, queue: queue); fallthrough
        case (.none, let e?): throw e
        case (.none, .none): fatalError("SQLite returned SQLITE_OK, but there was no database connection pointer. This should never happen.")
        }
        
        // 3. Enable everything needed for the database.
        error = queue.sync {
            // Extended error codes (to better understand problems)
            if let extendedEnablingCode = sqlite3_extended_result_codes(db, 1).enforce(.ok) {
                return IG.Error._unableToExtendErrorCodes(code: extendedEnablingCode)
            }
            
            // Foreign key constraints activation
            if let foreignEnablingCode = sqlite3_exec(db, "PRAGMA foreign_keys = ON", nil, nil, nil).enforce(.ok) {
                return IG.Error._unableToActivateForeignKeys(code: foreignEnablingCode)
            }
            
            return nil
        }
        
        // If there is an error, it shall be thrown in the calling queue.
        if let e = error {
            Self._destroy(database: db!, queue: queue)
            throw e
        }
        
        return (rootURL, db!)
    }
    
    /// Destroys/Deinitialize a low-level SQLite connection.
    /// - parameter database: The C pointer to the SQLite database.
    /// - parameter queue: The queue serializing access to the database.
    static func _destroy(database: SQLite.Database, queue: DispatchQueue) {
        queue.async {
            // Close the database connection normally.
            let closeResult = sqlite3_close(database)
            if closeResult == .ok { return }
            let closeLowlevelMessage = String(cString: sqlite3_errmsg(database))
            // If the connection cannot be closed, tell it to "auto-destroy" when any running statement is done.
            let scheduleResult = sqlite3_close_v2(database).result
            if scheduleResult == .ok { return }
            // If not even that couldn't be scheduled, just print the error and crash.
            let error = IG.Error._unableToCloseDB(code: scheduleResult, result: closeResult, message: closeLowlevelMessage)
            let secondMessage = String(cString: sqlite3_errmsg(database))
            if secondMessage != scheduleResult.description {
                error.errorUserInfo["Second closing message"] = secondMessage
            }
            fatalError(error.localizedDescription)
        }
    }
}

private extension IG.Error {
    /// Error raised when a SQLite command fails.
    static func _invalidExecution(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "Invalid SQLite execution.", help: "Review the returned error and try to fix the problem.", info: ["Error code": code])
    }
    /// Error raised when a SQLite command fails.
    static func _invalidExecution(error: Swift.Error) -> Self {
        Self(.database(.callFailed), "Invalid SQLite execution.", help: "Review the returned error and try to fix the problem.", underlying: error)
    }
    /// Error raised when the database location is invalid.
    static func _invalid(url: URL) -> Self {
        Self(.database(.invalidRequest), "The database location provided is not a valid file URL.", help: "Make sure the URL is of 'file://' domain", info: ["Root URL": url])
    }
    /// Error raised when the file path didn't contain any SQLite database.
    static func _unfoundDatabase(path: String) -> Self {
        Self(.database(.invalidRequest), "The database location didn't contain any SQLite database.", help: "Make sure the database is in location '\(path)'.")
    }
    /// Error raised when there is a file in the SQLite path.
    static func _conflictingFile(path: String) -> Self {
        Self(.database(.invalidRequest), "There is file in the given location.", help: "Delete any previous file in location \(path) or change the database configuration.")
    }
    /// Error raised when the file path cannot be recreated.
    static func _invalidPath(error: Swift.Error) -> Self {
        Self(.database(.invalidRequest), "When creating a database, the URL path couldn't be recreated.", help: "Make sure the rootURL and/or create all subfolders in between.", underlying: error)
    }
    /// Error raised when the database cannot be opened.
    static func _cannotOpenDB(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "The SQLite database couldn't be opened.", help: "Make sure you have access to the folder/file location.", info: ["Error code": code])
    }
    /// Error raised when SQLite cannot extend the error codes.
    static func _unableToExtendErrorCodes(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "The SQLite database couldn't enable extended result codes.", help: "Contact the repo maintainer.", info: ["Error code": code])
    }
    /// Error raised when SQLite cannot enable the foreign keys.
    static func _unableToActivateForeignKeys(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "Foreign keys couldn't be enabled for the database.", help: "Contact the repo maintainer.", info: ["Error code": code])
    }
    /// Error raised when the SQLite database cannot be closed.
    static func _unableToCloseDB(code: SQLite.Result, result: Int32, message: String) -> Self {
        Self(.database(.callFailed), "The SQLite database couldn't be properly close.", help: "A unexpected error was encountered. Please contact the repository maintainer and attach this debug print.", info: ["Error code": code, "First closing code": result, "First closing message": message])
    }
}
