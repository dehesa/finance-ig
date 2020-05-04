import Foundation
import SQLite3

extension IG.Database {
    /// Contains the low-level functionality related to the SQLite database.
    internal final class Channel {
        /// The queue handling all database accesses.
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
        init(location: IG.Database.Location, targetQueue: DispatchQueue?) throws {
            // Research: attributes: .concurrent
            self._queue = DispatchQueue(label: IG.Database.reverseDNS + ".queue.channel", qos: .default, autoreleaseFrequency: .inherit, target: targetQueue)
            (self.rootURL, self._database) = try Self._make(location: location, queue: _queue)
        }
        
        deinit {
            Self._destroy(database: self._database, queue: self._queue)
        }
    }
}

extension IG.Database.Channel {
    /// Reads and/or writes from the database directly (without any transaction).
    ///
    /// This is a barrier access, meaning that all other access are kept on hold while this interaction is in operation.
    /// - warning: Don't call another read or write within the `interaction` closure or a deadlock will occur.
    /// - parameter interaction: Closure giving the priviledge database connection.
    /// - parameter database: Low-level pointer to the SQLite database. Usage of this pointer outside the `interaction` closure produces a fatal error.
    /// - throws: Any error thrown by the `interaction` closure.
    /// - returns: The result returned in the `interaction` closure.
    internal func unrestrictedAccess<T>(_ interaction: (_ database: SQLite.Database) throws -> T) rethrows -> T {
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
    internal func read<T>(_ interaction: (_ database: SQLite.Database) throws -> T) rethrows -> T {
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
    internal func write<T>(_ interaction: (_ database: SQLite.Database) throws -> T) rethrows -> T {
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

extension IG.Database.Channel {
    /// Reads from the database in a transaction that is executed asynchronously.
    ///
    /// This is a parallel access, meaning that other read access may be performed in parallel.
    /// - warning: Don't call another read or write within the `interaction` closure or a deadlock will occur.
    /// - parameter promise: Closure receiving the result of the transaction (that one returned by the `interaction` closure).
    /// - parameter receptionQueue: The queue where the `promise` will be executed.
    /// - parameter interaction: Closure giving the priviledge database connection.
    /// - parameter database: Low-level pointer to the SQLite database. Usage of this pointer outside the `interaction` closure produces a fatal error.
    internal func readAsync<T>(promise: @escaping (Result<T,IG.Database.Error>) -> Void, on receptionQueue: DispatchQueue, _ interaction: @escaping (_ database: SQLite.Database) throws -> T) {
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
    internal func writeAsync<T>(promise: @escaping (Result<T,IG.Database.Error>) -> Void, on receptionQueue: DispatchQueue, _ interaction: @escaping (_ database: SQLite.Database) throws -> T) {
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
    private func _asyncTransactionAccess<T>(flags: DispatchWorkItemFlags, promise: @escaping (Result<T,IG.Database.Error>) -> Void, on receptionQueue: DispatchQueue, _ interaction: @escaping (_ database: SQLite.Database) throws -> T) {
        self._queue.async(flags: flags) {
            if let errorCode = sqlite3_exec(self._database, "BEGIN TRANSACTION", nil, nil, nil).enforce(.ok) {
                return receptionQueue.async {
                    promise(.failure( .callFailed(.execCommand, code: errorCode) ))
                }
            }
            
            let output: T
            do {
                output = try interaction(self._database)
            } catch let error {
                if let errorCode = sqlite3_exec(self._database, "ROLLBACK", nil, nil, nil).enforce(.ok) {
                    fatalError("An error occurred (code: \(errorCode) trying to rollback an operation")
                }
                
                return receptionQueue.async {
                    promise(.failure( .transform(error) ))
                }
            }
            
            if let errorCode = sqlite3_exec(self._database, "END TRANSACTION", nil, nil, nil).enforce(.ok) {
                fatalError("An error occurred (code: \(errorCode) trying to end a transaction")
            }
            
            return receptionQueue.async {
                promise(.success(output))
            }
        }
    }
}

private extension IG.Database.Channel {
    /// Opens or creates a SQLite database and returns the pointer handler to it.
    /// - warning: This function will perform a `queue.sync()` operation. Be sure no deadlocks occurs.
    /// - parameter location: The location of the database (whether "in-memory" or file system).
    /// - parameter queue: The queue serializing access to the database.
    /// - throws: `IG.Database.Error` exclusively.
    static func _make(location: IG.Database.Location, queue: DispatchQueue) throws -> (rootURL: URL?, database: SQLite.Database) {
        let (rootURL, path): (URL?, String)
        
        // 1. Define file path (or in-memory keyword)
        switch location {
        case .inMemory:
            (rootURL, path) = (nil, ":memory:")
        case .file(let url, let expectsExistance):
            (rootURL, path) = (url, url.path)
            // Check the URL is valid
            guard url.isFileURL else {
                var error = IG.Database.Error.invalidRequest("The database location provided is not a valid file URL", suggestion: "Make sure the URL is of 'file://' domain")
                error.context.append(("Root URL", url))
                throw error
            }
            
            switch expectsExistance {
            case .some(true):
                guard FileManager.default.fileExists(atPath: path) else {
                    throw IG.Database.Error.invalidRequest("The database location didn't contain any SQLite database", suggestion: .init("Make sure the database is in location '\(path)'"))
                }
            case .some(false):
                guard !FileManager.default.fileExists(atPath: path) else {
                    throw IG.Database.Error.invalidRequest("There is file in the given location", suggestion: .init("Delete any previous file in location \(path) or change the database configuration"))
                }
                fallthrough
            case .none:
                // Check the path to the file exists and if not create any intermediate path.
                if !FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path, isDirectory: nil) {
                    do {
                        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                    } catch let error {
                        throw IG.Database.Error.invalidRequest("When creating a database, the URL path couldn't be recreated", underlying: error, suggestion: "Make sure the rootURL and/or create all subfolders in between")
                    }
                }
            }
        }
        
        // 2. Open/Create the database connection
        var db: SQLite.Database? = nil
        var error: IG.Database.Error? = nil
        
        queue.sync {
            let openFlags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX  /* SQLITE_OPEN_FULLMUTEX */
            if let errorCode = sqlite3_open_v2(path, &db, openFlags, nil).enforce(.ok) {
                error = IG.Database.Error.callFailed("The SQLite database couldn't be opened", code: errorCode)
                if let channel = db {
                    let message = String(cString: sqlite3_errmsg(channel))
                    if message != errorCode.description {
                        error?.context.append(("Open error message", message))
                    }
                }
            }
        }
        
        // If there is an error, it shall be thrown in the calling queue
        switch (db, error) {
        case (.some,  .none):  break
        case (let c?, let e?): Self._destroy(database: c, queue: queue); fallthrough
        case (.none,  let e?): throw e
        case (.none,  .none):  fatalError("SQLite returned SQLITE_OK, but there was no database connection pointer. This should never happen")
        }
        
        // 3. Enable everything needed for the database.
        queue.sync {
            // Extended error codes (to better understand problems)
            if let extendedEnablingCode = sqlite3_extended_result_codes(db, 1).enforce(.ok) {
                error = .callFailed("The SQLite database couldn't enable extended result codes", code: extendedEnablingCode)
                return
            }
            
            // Foreign key constraints activation
            if let foreignEnablingCode = sqlite3_exec(db, "PRAGMA foreign_keys = ON", nil, nil, nil).enforce(.ok) {
                error = .callFailed("Foreign keys couldn't be enabled for the database", code: foreignEnablingCode)
                return
            }
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
            var error: Database.Error = .callFailed("The SQLite database coudln't be properly close", code: scheduleResult, suggestion: Database.Error.Suggestion.fileBug)
            error.context.append(("First closing code", closeResult))
            error.context.append(("First closing message", closeLowlevelMessage))
            
            let secondMessage = String(cString: sqlite3_errmsg(database))
            if secondMessage != scheduleResult.description {
                error.context.append(("Second closing message", secondMessage))
            }
            fatalError(error.debugDescription)
        }
    }
}
