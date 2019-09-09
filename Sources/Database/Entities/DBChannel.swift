import Foundation
import SQLite3

extension IG.DB {
    /// Listing of functions to perform on the SQLite raw pointer.
    internal enum Channel {
        /// Opens or creates a SQLite database and returns the pointer handler to it.
        /// - parameter channel: The C pointer to the SQLite database.
        /// - parameter queue: The queue serializing access to the database. 
        /// - throws: `IG.DB.Error` exclusively.
        /// - warning: This function will perform a `queue.sync()` operation. Be sure no deadlocks occurs.
        static func make(rootURL: URL?, on queue: DispatchQueue) throws -> OpaquePointer {
            let path: String

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
            
            var db: OpaquePointer? = nil
            try queue.sync {
                let openFlags = SQLITE_OPEN_NOMUTEX | (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE)
                let openResult = sqlite3_open_v2(path, &db, openFlags, nil).result
                guard openResult == .ok else {
                    var error = IG.DB.Error.callFailed("The SQLite database couldn't be opened", code: openResult, lowlevel: nil, suggestion: .reviewError)
                    if let channel = db {
                        error.lowlevel = String(cString: sqlite3_errmsg(channel))
                        Self.destroy(channel: channel, on: queue)
                    }
                    throw error
                }
            }
            
            guard let channel = db else { fatalError("SQLite returned SQLITE_OK, but there was no pointer. This should never happen") }
            return channel
        }
        
        /// Destroys/Deinitialize a low-level SQLite connection.
        /// - parameter channel: The C pointer to the SQLite database.
        /// - parameter queue: The queue serializing access to the database.
        static func destroy(channel: OpaquePointer, on queue: DispatchQueue) {
            queue.async {
                // Close the database connection normally.
                let closeResult = sqlite3_close(channel)
                if closeResult == .ok { return }
                let closeLowlevelMessage = String(cString: sqlite3_errmsg(channel))
                // If the connection cannot be closed, tell it to "auto-destroy" when any running statement is done.
                let scheduleResult = sqlite3_close_v2(channel).result
                if scheduleResult == .ok { return }
                // If not even that couldn't be scheduled, just print the error and crash.
                var error: DB.Error = .callFailed("The SQLite database coudln't be properly close", code: scheduleResult, lowlevel: String(cString: sqlite3_errmsg(channel)), suggestion: DB.Error.Suggestion.fileBug)
                error.context.append(("First closing code", closeResult))
                error.context.append(("First closing messge", closeLowlevelMessage))
                fatalError(error.debugDescription)
            }
        }
    }
}