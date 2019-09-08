import SQLite3
import Foundation

/// Namespace for `SQLite` related entities and functionality.
internal enum SQLite {
    /// A result code retrieve from a low-level SQLite routine.
    internal struct Result: RawRepresentable, Equatable, CustomStringConvertible {
        private var value: Int32
        
        init?(rawValue: Int32) {
            // All none supported errors print the same hard-coded string.
            guard sqlite3_errstr(rawValue)! != sqlite3_errstr(SQLITE_FORMAT)! else { return nil }
            self.init(trusted: rawValue)
        }
        
        /// Designated initializer trusting the given value.
        fileprivate init(trusted rawValue: Int32) {
            self.value = rawValue
        }
        
        var rawValue: Int32 {
            return self.value
        }
        
        var description: String {
            guard let pointer = sqlite3_errstr(self.value) else { fatalError("The receiving result \"\(self.value)\" is not an SQLite result.") }
            return .init(cString: pointer)
        }
    }
}

extension SQLite.Result {
    /// Booleain indicating whether the receiving result is "just" a primary result or it is a extended result.
    var isPrimary: Bool {
        return !self.isExtended
    }
    /// Boolean indicating whether the result code is in the extended error category.
    var isExtended: Bool {
        return (self.value >> 8) > 0
    }
}

extension Int32 {
    /// Returns the result representation of an SQLite result.
    /// - precondition: This function expect the value to be a correct SQLite result. No conditions are performed.
    var result: IG.SQLite.Result {
        return .init(trusted: self)
    }
    
    /// It compares the receiving SQLite `Int32` result with the passed `result` and if it doesn't match, it throws an error with the given `error` and `suggestion`. If the results match, no operation is performed.
    ///
    /// - parameter result: The expected SQLite result.
    /// - parameter error: The error message to pass to the `IG.DB.Error` (if necessary).
    /// - parameter suggestion: The error suggestion to pass to the `IG.DB.Error` (if necessary).
    /// - parameter handler: A closure that is only executed if the results don't match, so it lets you handle the error. It also pass the error that will be thrown at the end of this function.
    func expecting(_ result: IG.SQLite.Result, error: @autoclosure ()->String, suggestion: @autoclosure ()->String = IG.DB.Error.Suggestion.reviewError, handler: ((inout IG.DB.Error)->Void)? = nil) throws {
        guard self != result.rawValue else { return }
        
        var error = IG.DB.Error.callFailed(error(), code: .init(trusted: self), underlying: nil, suggestion: suggestion())
        handler?(&error)
        throw error
    }
    
    static func == (lhs: Self, rhs: IG.SQLite.Result) -> Bool {
        return lhs == rhs.rawValue
    }
}


extension IG.SQLite.Result {
    // Successful result
    internal static var ok: Self            { Self(trusted: SQLITE_OK) }
    // sqlite3_step() has another row ready
    internal static var row: Self           { Self(trusted: SQLITE_ROW) }
    // sqlite3_step() has finished executing
    internal static var done: Self          { Self(trusted: SQLITE_DONE) }
    
    // Notifications from sqlite3_log()
    internal static var notice: Self        { Self(trusted: SQLITE_NOTICE) }
    // Warnings from sqlite3_log()
    internal static var warnings: Self      { Self(trusted: SQLITE_WARNING) }
    
    // Generic error
    internal static var errorGeneric: Self  { Self(trusted: SQLITE_ERROR) }
    // Access permission denied
    internal static var errorPermissionDenied: Self { Self(trusted: SQLITE_PERM) }
    // Callback routine requested an abort
    internal static var errorAbort: Self    { Self(trusted: SQLITE_ABORT) }
    // The database file is locked
    internal static var errorBusy: Self     { Self(trusted: SQLITE_BUSY) }
    // A table in the database is locked
    internal static var errorLocked: Self   { Self(trusted: SQLITE_LOCKED) }
    // A malloc() failed
    internal static var errorNoMemory: Self { Self(trusted: SQLITE_NOMEM) }
    // Attempt to write a readonly database
    internal static var errorReadOnly: Self { Self(trusted: SQLITE_READONLY) }
    // Operation terminated by sqlite3_interr
    internal static var errorInterrupt: Self { Self(trusted: SQLITE_INTERRUPT) }
    // Some kind of disk I/O error occurred
    internal static var errorIO: Self       { Self(trusted: SQLITE_IOERR) }
    // The database disk image is malformed
    internal static var errorCorrupt: Self  { Self(trusted: SQLITE_CORRUPT) }
    // Unknown opcode in sqlite3_file_control(
    internal static var errorNotFound: Self { Self(trusted: SQLITE_NOTFOUND) }
    // Insertion failed because database is full
    internal static var errorFull: Self     { Self(trusted: SQLITE_FULL) }
    // Unable to open the database file
    internal static var errorCantOpen: Self { Self(trusted: SQLITE_CANTOPEN) }
    // Database lock protocol error
    internal static var errorProtocol: Self { Self(trusted: SQLITE_PROTOCOL) }
    // The database schema changed
    internal static var errorSchema: Self   { Self(trusted: SQLITE_SCHEMA) }
    // String or BLOB exceeds size limit
    internal static var errorTooBig: Self   { Self(trusted: SQLITE_TOOBIG) }
    // Abort due to constraint violation
    internal static var errorConstraint: Self { Self(trusted: SQLITE_CONSTRAINT) }
    // Data type mismatch
    internal static var errorMismatch: Self { Self(trusted: SQLITE_MISMATCH) }
    // Library used incorrectly
    internal static var errorMisuse: Self   { Self(trusted: SQLITE_MISUSE) }
    // Authorization denied
    internal static var errorAuthorizationDenied: Self { Self(trusted: SQLITE_AUTH) }
    // 2nd parameter to sqlite3_bind out of range
    internal static var errorRange: Self    { Self(trusted: SQLITE_RANGE) }
    // File opened that is not a database file
    internal static var errorNotDB: Self    { Self(trusted: SQLITE_NOTADB) }
}

// MARK: - Future Use

//private let primary: [(value: Int32, name: String, print: String)] = [
//    (SQLITE_OK,          "SQLITE_OK",         "Successful result"),
//    (SQLITE_ERROR,       "SQLITE_ERROR",      "Generic error"),
//    (SQLITE_INTERNAL,    "SQLITE_INTERNAL",   "Internal logic error in SQLite"),                 // Not supported
//    (SQLITE_PERM,        "SQLITE_PERM",       "Access permission denied"),
//    (SQLITE_ABORT,       "SQLITE_ABORT",      "Callback routine requested an abort"),
//    (SQLITE_BUSY,        "SQLITE_BUSY",       "The database file is locked"),
//    (SQLITE_LOCKED,      "SQLITE_LOCKED",     "A table in the database is locked"),
//    (SQLITE_NOMEM,       "SQLITE_NOMEM",      "A malloc() failed"),
//    (SQLITE_READONLY,    "SQLITE_READONLY",   "Attempt to write a readonly database"),
//    (SQLITE_INTERRUPT,   "SQLITE_INTERRUPT",  "Operation terminated by sqlite3_interr"),
//    (SQLITE_IOERR,       "SQLITE_IOERR",      "Some kind of disk I/O error occurred"),
//    (SQLITE_CORRUPT,     "SQLITE_CORRUPT",    "The database disk image is malformed"),
//    (SQLITE_NOTFOUND,    "SQLITE_NOTFOUND",   "Unknown opcode in sqlite3_file_control("),
//    (SQLITE_FULL,        "SQLITE_FULL",       "Insertion failed because database is full"),
//    (SQLITE_CANTOPEN,    "SQLITE_CANTOPEN",   "Unable to open the database file"),
//    (SQLITE_PROTOCOL,    "SQLITE_PROTOCOL",   "Database lock protocol error"),
//    (SQLITE_EMPTY,       "SQLITE_EMPTY",      "Internal use only"),                              // Not supported
//    (SQLITE_SCHEMA,      "SQLITE_SCHEMA",     "The database schema changed"),
//    (SQLITE_TOOBIG,      "SQLITE_TOOBIG",     "String or BLOB exceeds size limit"),
//    (SQLITE_CONSTRAINT,  "SQLITE_CONSTRAINT", "Abort due to constraint violation"),
//    (SQLITE_MISMATCH,    "SQLITE_MISMATCH",   "Data type mismatch"),
//    (SQLITE_MISUSE,      "SQLITE_MISUSE",     "Library used incorrectly"),
//    (SQLITE_NOLFS,       "SQLITE_NOLFS",      "Uses OS features not supported on host"),         // Not supported
//    (SQLITE_AUTH,        "SQLITE_AUTH",       "Authorization denied"),
//    (SQLITE_FORMAT,      "SQLITE_FORMAT",     "Not used"),                                       // Not supported
//    (SQLITE_RANGE,       "SQLITE_RANGE",      "2nd parameter to sqlite3_bind out of range"),
//    (SQLITE_NOTADB,      "SQLITE_NOTADB",     "File opened that is not a database file"),
//    (SQLITE_NOTICE,      "SQLITE_NOTICE",     "Notifications from sqlite3_log()"),
//    (SQLITE_WARNING,     "SQLITE_WARNING",    "Warnings from sqlite3_log()"),
//    (SQLITE_ROW,         "SQLITE_ROW",        "sqlite3_step() has another row ready"),
//    (SQLITE_DONE,        "SQLITE_DONE",       "sqlite3_step() has finished executing")
//]
//
//private let secondary: [(value: Int32, name: String, print: String)] = [
//    (SQLITE_IOERR  | (1<<8),     "SQLITE_IOERR_READ",              "disk I/O error"),
//    (SQLITE_IOERR  | (2<<8),     "SQLITE_IOERR_SHORT_READ",        "disk I/O error"),
//    (SQLITE_IOERR  | (3<<8),     "SQLITE_IOERR_WRITE",             "disk I/O error"),
//    (SQLITE_IOERR  | (4<<8),     "SQLITE_IOERR_FSYNC",             "disk I/O error"),
//    (SQLITE_IOERR  | (5<<8),     "SQLITE_IOERR_DIR_FSYNC",         "disk I/O error"),
//    (SQLITE_IOERR  | (6<<8),     "SQLITE_IOERR_TRUNCATE",          "disk I/O error"),
//    (SQLITE_IOERR  | (7<<8),     "SQLITE_IOERR_FSTAT",             "disk I/O error"),
//    (SQLITE_IOERR  | (8<<8),     "SQLITE_IOERR_UNLOCK",            "disk I/O error"),
//    (SQLITE_IOERR  | (9<<8),     "SQLITE_IOERR_RDLOCK",            "disk I/O error"),
//    (SQLITE_IOERR  | (10<<8),    "SQLITE_IOERR_DELETE",            "disk I/O error"),
//    (SQLITE_IOERR  | (11<<8),    "SQLITE_IOERR_BLOCKED",           "disk I/O error"),
//    (SQLITE_IOERR  | (12<<8),    "SQLITE_IOERR_NOMEM",             "disk I/O error"),
//    (SQLITE_IOERR  | (13<<8),    "SQLITE_IOERR_ACCESS",            "disk I/O error"),
//    (SQLITE_IOERR  | (14<<8),    "SQLITE_IOERR_CHECKRESERVEDLOCK", "disk I/O error"),
//    (SQLITE_IOERR  | (15<<8),    "SQLITE_IOERR_LOCK",              "disk I/O error"),
//    (SQLITE_IOERR  | (16<<8),    "SQLITE_IOERR_CLOSE",             "disk I/O error"),
//    (SQLITE_IOERR  | (17<<8),    "SQLITE_IOERR_DIR_CLOSE",         "disk I/O error"),
//    (SQLITE_IOERR  | (18<<8),    "SQLITE_IOERR_SHMOPEN",           "disk I/O error"),
//    (SQLITE_IOERR  | (19<<8),    "SQLITE_IOERR_SHMSIZE",           "disk I/O error"),
//    (SQLITE_IOERR  | (20<<8),    "SQLITE_IOERR_SHMLOCK",           "disk I/O error"),
//    (SQLITE_IOERR  | (21<<8),    "SQLITE_IOERR_SHMMAP",            "disk I/O error"),
//    (SQLITE_IOERR  | (22<<8),    "SQLITE_IOERR_SEEK",              "disk I/O error"),
//    (SQLITE_IOERR  | (23<<8),    "SQLITE_IOERR_DELETE_NOENT",      "disk I/O error"),
//    (SQLITE_IOERR  | (24<<8),    "SQLITE_IOERR_MMAP",              "disk I/O error"),
//    (SQLITE_IOERR  | (25<<8),    "SQLITE_IOERR_GETTEMPPATH",       "disk I/O error"),
//    (SQLITE_IOERR  | (26<<8),    "SQLITE_IOERR_CONVPATH",          "disk I/O error"),
//    (SQLITE_IOERR  | (27<<8),    "SQLITE_IOERR_VNODE",             "disk I/O error"),
//    (SQLITE_IOERR  | (28<<8),    "SQLITE_IOERR_AUTH",              "disk I/O error"),
//    (SQLITE_LOCKED |  (1<<8),    "SQLITE_LOCKED_SHAREDCACHE",      "database table is locked"),
//    (SQLITE_BUSY   |  (1<<8),    "SQLITE_BUSY_RECOVERY",           "database is locked"),
//    (SQLITE_BUSY   |  (2<<8),    "SQLITE_BUSY_SNAPSHOT",           "database is locked"),
//    (SQLITE_CANTOPEN | (1<<8),   "SQLITE_CANTOPEN_NOTEMPDIR",      "unable to open database file"),
//    (SQLITE_CANTOPEN | (2<<8),   "SQLITE_CANTOPEN_ISDIR",          "unable to open database file"),
//    (SQLITE_CANTOPEN | (3<<8),   "SQLITE_CANTOPEN_FULLPATH",       "unable to open database file"),
//    (SQLITE_CANTOPEN | (4<<8),   "SQLITE_CANTOPEN_CONVPATH",       "unable to open database file"),
//    (SQLITE_CORRUPT  | (1<<8),   "SQLITE_CORRUPT_VTAB",            "database disk image is malformed"),
//    (SQLITE_READONLY | (1<<8),   "SQLITE_READONLY_RECOVERY",       "attempt to write a readonly database"),
//    (SQLITE_READONLY | (2<<8),   "SQLITE_READONLY_CANTLOCK",       "attempt to write a readonly database"),
//    (SQLITE_READONLY | (3<<8),   "SQLITE_READONLY_ROLLBACK",       "attempt to write a readonly database"),
//    (SQLITE_READONLY | (4<<8),   "SQLITE_READONLY_DBMOVED",        "attempt to write a readonly database"),
//    (SQLITE_ABORT    | (2<<8),   "SQLITE_ABORT_ROLLBACK",          "abort due to ROLLBACK"),
//    (SQLITE_CONSTRAINT | (1<<8), "SQLITE_CONSTRAINT_CHECK",        "constraint failed"),
//    (SQLITE_CONSTRAINT | (2<<8), "SQLITE_CONSTRAINT_COMMITHOOK",   "constraint failed"),
//    (SQLITE_CONSTRAINT | (3<<8), "SQLITE_CONSTRAINT_FOREIGNKEY",   "constraint failed"),
//    (SQLITE_CONSTRAINT | (4<<8), "SQLITE_CONSTRAINT_FUNCTION",     "constraint failed"),
//    (SQLITE_CONSTRAINT | (5<<8), "SQLITE_CONSTRAINT_NOTNULL",      "constraint failed"),
//    (SQLITE_CONSTRAINT | (6<<8), "SQLITE_CONSTRAINT_PRIMARYKEY",   "constraint failed"),
//    (SQLITE_CONSTRAINT | (7<<8), "SQLITE_CONSTRAINT_TRIGGER",      "constraint failed"),
//    (SQLITE_CONSTRAINT | (8<<8), "SQLITE_CONSTRAINT_UNIQUE",       "constraint failed"),
//    (SQLITE_CONSTRAINT | (9<<8), "SQLITE_CONSTRAINT_VTAB",         "constraint failed"),
//    (SQLITE_CONSTRAINT | (10<<8),"SQLITE_CONSTRAINT_ROWID",        "constraint failed"),
//    (SQLITE_NOTICE   | (1<<8),   "SQLITE_NOTICE_RECOVER_WAL",      "notification message"),
//    (SQLITE_NOTICE   | (2<<8),   "SQLITE_NOTICE_RECOVER_ROLLBACK", "notification message"),
//    (SQLITE_WARNING  | (1<<8),   "SQLITE_WARNING_AUTOINDEX",       "warning message"),
//    (SQLITE_AUTH     | (1<<8),   "SQLITE_AUTH_USER",               "authorization denied"),
//    (SQLITE_OK       | (1<<8),   "SQLITE_OK_LOAD_PERMANENTLY",     "not an error")
//]
