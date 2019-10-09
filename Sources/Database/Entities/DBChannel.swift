import Foundation
import SQLite3

extension IG.DB {
    /// Contains the low-level functionality related to the SQLite database.
    internal final class Channel {
        /// The queue handling all database accesses.
        private let queue: DispatchQueue
        /// The underlying SQLite instance (referencing the SQLite file).
        private let database: SQLite.Database
        
        /// Designated initializer creating/opening the SQLite database indicated by the `rootURL`.
        /// - parameter rootURL: The file location or `nil` for "in memory" storage.
        /// - parameter queue: The queue serializing access to the database.
        init(rootURL: URL?, queue: DispatchQueue) throws {
            self.queue = queue
            self.database = try Self.make(rootURL: rootURL, queue: queue)
        }
        
        deinit {
            Self.destroy(database: self.database, queue: self.queue)
        }
    }
}

extension IG.DB.Channel {
    internal func unrestrictedAccess<T>(_ interaction: (_ database: SQLite.Database) throws -> T) rethrows -> T {
        dispatchPrecondition(condition: .notOnQueue(self.queue))
        return try self.queue.sync {
            try interaction(self.database)
        }
    }
    
    /// Reads from the database in a transaction.
    ///
    /// This is a parallel access, meaning that other read access may be performed in parallel.
    /// - warning: Don't call another read or write within the `interaction` closure or a deadlock will occur.
    /// - parameter interaction: Closure giving the priviledge database connection.
    /// - todo: Make parallel reads (currently they are serial).
    internal func read<T>(_ interaction: (_ database: SQLite.Database) throws -> T) rethrows -> T {
        try self.write(interaction)
    }
    
    /// Reads from the database in a transaction that is executed asynchronously.
    ///
    /// This is a parallel access, meaning that other read access may be performed in parallel.
    /// - warning: Don't call another read or write within the `interaction` closure or a deadlock will occur.
    /// - parameter promise: Closure receiving the result of the transaction (that one returned by the `interaction` closure).
    /// - parameter receptionQueue: The queue where the `promise` will be executed.
    /// - parameter interaction: Closure giving the priviledge database connection.
    /// - todo: Make parallel reads (currently they are serial).
    internal func readAsync<T>(promise: @escaping (Result<T,IG.DB.Error>) -> Void, on receptionQueue: DispatchQueue, _ interaction: @escaping (_ database: SQLite.Database) throws -> T) {
        self.writeAsync(promise: promise, on: receptionQueue, interaction)
    }
    
    /// Reads and/or writes from the database in a transaction.
    ///
    /// This is a barrier access, meaning that all other access are kept on hold while this interaction is in operation.
    /// - warning: Don't call another read or write within the `interaction` closure or a deadlock will occur.
    /// - parameter interaction: Closure giving the priviledge database connection.
    internal func write<T>(_ interaction: (_ database: SQLite.Database) throws -> T) rethrows -> T {
        dispatchPrecondition(condition: .notOnQueue(self.queue))
        return try self.queue.sync {
            try sqlite3_exec(self.database, "BEGIN TRANSACTION", nil, nil, nil).expects(.ok)
            
            let output: T
            do {
                output = try interaction(self.database)
            } catch let error {
                if let errorCode = sqlite3_exec(self.database, "ROLLBACK", nil, nil, nil).enforce(.ok) {
                    fatalError("An error occurred (code: \(errorCode) trying to rollback an operation")
                }
                throw error
            }
            
            if let errorCode = sqlite3_exec(self.database, "END TRANSACTION", nil, nil, nil).enforce(.ok) {
                fatalError("An error occurred (code: \(errorCode) trying to end a transaction")
            }
            return output
        }
    }
    
    /// Reads and/or writes from the database in a transaction.
    ///
    /// This is a barrier access, meaning that all other access are kept on hold while this interaction is in operation.
    /// - warning: Don't call another read or write within the `interaction` closure or a deadlock will occur.
    /// - parameter promise: Closure receiving the result of the transaction (that one returned by the `interaction` closure).
    /// - parameter receptionQueue: The queue where the `promise` will be executed.
    /// - parameter interaction: Closure giving the priviledge database connection.
    internal func writeAsync<T>(promise: @escaping (Result<T,IG.DB.Error>) -> Void, on receptionQueue: DispatchQueue, _ interaction: @escaping (_ database: SQLite.Database) throws -> T) {
        dispatchPrecondition(condition: .notOnQueue(self.queue))
        self.queue.async {
            if let errorCode = sqlite3_exec(self.database, "BEGIN TRANSACTION", nil, nil, nil).enforce(.ok) {
                return receptionQueue.async {
                    promise(.failure( .callFailed(.execCommand, code: errorCode) ))
                }
            }
            
            let output: T
            do {
                output = try interaction(self.database)
            } catch let error {
                if let errorCode = sqlite3_exec(self.database, "ROLLBACK", nil, nil, nil).enforce(.ok) {
                    fatalError("An error occurred (code: \(errorCode) trying to rollback an operation")
                }
                
                return receptionQueue.async {
                    promise(.failure( .transform(error) ))
                }
            }
            
            if let errorCode = sqlite3_exec(self.database, "END TRANSACTION", nil, nil, nil).enforce(.ok) {
                fatalError("An error occurred (code: \(errorCode) trying to end a transaction")
            }
            
            return receptionQueue.async {
                promise(.success(output))
            }
        }
    }
}

extension IG.DB.Channel {
    /// Opens or creates a SQLite database and returns the pointer handler to it.
    /// - warning: This function will perform a `queue.sync()` operation. Be sure no deadlocks occurs.
    /// - parameter rootURL: The file location or `nil` for "in memory" storage.
    /// - parameter queue: The queue serializing access to the database.
    /// - throws: `IG.DB.Error` exclusively.
    private static func make(rootURL: URL?, queue: DispatchQueue) throws -> SQLite.Database {
        let path: String
        
        // 1. Define file path (or in-memory keyword)
        switch rootURL {
        case .none:
            path = ":memory:"
        case .some(let url):
            guard url.isFileURL else {
                var error = IG.DB.Error.invalidRequest(#"The database location provided is not a valid file URL"#, suggestion: #"Make sure the URL is of "file://" domain"#)
                error.context.append(("Root URL", url))
                throw error
            }
            
            if !FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path, isDirectory: nil) {
                do {
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                } catch let error {
                    throw IG.DB.Error.invalidRequest("When creating a database, the URL path couldn't be recreated", underlying: error, suggestion: "Make sure the rootURL and/or create all subfolders in between")
                }
            }
            
            path = url.path
        }
        
        // 2. Open/Create the database connection
        var db: SQLite.Database? = nil
        var error: IG.DB.Error? = nil
        
        queue.sync {
            let openFlags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX
            if let errorCode = sqlite3_open_v2(path, &db, openFlags, nil).enforce(.ok) {
                error = IG.DB.Error.callFailed("The SQLite database couldn't be opened", code: errorCode)
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
        case (let c?, let e?): Self.destroy(database: c, queue: queue); fallthrough
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
            Self.destroy(database: db!, queue: queue)
            throw e
        }
        
        return db!
    }
    
    /// Destroys/Deinitialize a low-level SQLite connection.
    /// - parameter database: The C pointer to the SQLite database.
    /// - parameter queue: The queue serializing access to the database.
    private static func destroy(database: SQLite.Database, queue: DispatchQueue) {
        queue.async {
            // Close the database connection normally.
            let closeResult = sqlite3_close(database)
            if closeResult == .ok { return }
            let closeLowlevelMessage = String(cString: sqlite3_errmsg(database))
            // If the connection cannot be closed, tell it to "auto-destroy" when any running statement is done.
            let scheduleResult = sqlite3_close_v2(database).result
            if scheduleResult == .ok { return }
            // If not even that couldn't be scheduled, just print the error and crash.
            var error: DB.Error = .callFailed("The SQLite database coudln't be properly close", code: scheduleResult, suggestion: DB.Error.Suggestion.fileBug)
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
