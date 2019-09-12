import Foundation
import SQLite3

extension IG.DB {
    /// Listing of functions to perform on the SQLite raw pointer.
    internal enum Channel {
        /// Opens or creates a SQLite database and returns the pointer handler to it.
        /// - warning: This function will perform a `queue.sync()` operation. Be sure no deadlocks occurs.
        /// - parameter channel: The C pointer to the SQLite database.
        /// - parameter queue: The queue serializing access to the database.
        /// - throws: `IG.DB.Error` exclusively.
        static func make(rootURL: URL?, on queue: DispatchQueue) throws -> SQLite.Database {
            let path: String
            
            // 1. Define file path (or in memory keyword)
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
            case (let c?, let e?): Self.destroy(channel: c, on: queue); fallthrough
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
                let statement = "PRAGMA foreign_keys = ON;"
                if let foreignEnablingCode = sqlite3_exec(db, statement, nil, nil, nil).enforce(.ok) {
                    error = .callFailed("Foreign keys couldn't be enabled for the database", code: foreignEnablingCode)
                    return
                }
            }
            
            // If there is an error, it shall be thrown in the calling queue.
            if let e = error {
                Self.destroy(channel: db!, on: queue)
                throw e
            }
            
            return db!
        }
        
        /// Destroys/Deinitialize a low-level SQLite connection.
        /// - parameter channel: The C pointer to the SQLite database.
        /// - parameter queue: The queue serializing access to the database.
        static func destroy(channel: SQLite.Database, on queue: DispatchQueue) {
            queue.async {
                // Close the database connection normally.
                let closeResult = sqlite3_close(channel)
                if closeResult == .ok { return }
                let closeLowlevelMessage = String(cString: sqlite3_errmsg(channel))
                // If the connection cannot be closed, tell it to "auto-destroy" when any running statement is done.
                let scheduleResult = sqlite3_close_v2(channel).result
                if scheduleResult == .ok { return }
                // If not even that couldn't be scheduled, just print the error and crash.
                var error: DB.Error = .callFailed("The SQLite database coudln't be properly close", code: scheduleResult, suggestion: DB.Error.Suggestion.fileBug)
                error.context.append(("First closing code", closeResult))
                error.context.append(("First closing message", closeLowlevelMessage))
                
                let secondMessage = String(cString: sqlite3_errmsg(channel))
                if secondMessage != scheduleResult.description {
                    error.context.append(("Second closing message", secondMessage))
                }
                fatalError(error.debugDescription)
            }
        }
    }
}
