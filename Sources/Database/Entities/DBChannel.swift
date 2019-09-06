import SQLite3
import Foundation

extension IG.DB {
    /// Listing of functions to perform on the SQLite raw pointer.
    internal enum Channel {
        /// Opens or creates a SQLite database and returns the pointer handler to it.
        /// - parameter channel: The C pointer to the SQLite database.
        /// - parameter queue: The queue serializing access to the database. 
        /// - throws: `IG.DB.Error` exclusively.
        static func make(rootURL: URL?, on queue: DispatchQueue) throws -> OpaquePointer {
            let path: String
            
            switch rootURL {
            case .none:
                path = ":memory:"
            case .some(let url):
                guard url.isFileURL else {
                    var error: IG.DB.Error = .invalidRequest(#"The database location provided is not a valid file URL."#, suggestion: #"Make sure the URL is of "file://" domain."#)
                    error.context.append(("rootURL", url))
                    throw error
                }
                
                do {
                    if !FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path, isDirectory: nil) {
                        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                    }
                } catch let error {
                    throw IG.DB.Error.invalidRequest("When creating a database, the URL path couldn't be recreated.", underlying: error, suggestion: "Make sure the rootURL is valid and try again")
                }
                
                path = url.path
            }
            
            var db: OpaquePointer? = nil
            let openFlags = SQLITE_OPEN_NOMUTEX | (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE)
            let openResult = sqlite3_open_v2(path, &db, openFlags, nil).result
            guard openResult.isOK else {
                if case .some(let channel) = db {
                    Self.destroy(channel: channel, on: queue)
                }
                
                throw IG.DB.Error.callFailed("The SQLite database couldn't be opened.", code: openResult, suggestion: IG.DB.Error.Suggestion.reviewError)
            }
            
            guard let channel = db else { fatalError("SQLite returned OK, but there was no pointer. This should never happen.") }
            return channel
        }
        
        /// Destroys/Deinitialize a low-level SQLite connection.
        /// - parameter channel: The C pointer to the SQLite database.
        /// - parameter queue: The queue serializing access to the database.
        static func destroy(channel: OpaquePointer, on queue: DispatchQueue) {
            queue.sync {
                // Close the database connection normally.
                if sqlite3_close(channel).result.isOK { return }
                // If the connection cannot be closed, tell it to "auto-destroy" when any running statement is done.
                let scheduleResult = sqlite3_close_v2(channel).result
                if scheduleResult.isOK { return }
                // If not even that couldn't be scheduled, just print the error and leave.
                let error: DB.Error = .callFailed("The SQlite database coudln't be closed properly", code: scheduleResult, suggestion: DB.Error.Suggestion.bug)
                fatalError(error.debugDescription)
            }
        }
    }
}

///
internal enum SQLite {
    ///
    internal struct Result: RawRepresentable {
        ///
        private var value: Int32
        
        init?(rawValue: Int32) {
            #warning("Figure this thing next!")
            fatalError()
        }
        
        var rawValue: Int32 {
            return self.value
        }
        
        var isOK: Bool {
            fatalError()
        }
    }
}

extension Int32 {
    ///
    var result: SQLite.Result {
        return SQLite.Result(rawValue: self)!
    }
}
