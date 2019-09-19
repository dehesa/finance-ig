import Foundation
import SQLite3

/// Namespace for `SQLite` related entities and functionality.
internal enum SQLite {
    /// Database connection pointing to underlying SQL structure.
    typealias Database = OpaquePointer
    /// Pointer to a compiled SQL statement.
    typealias Statement = OpaquePointer
    
    /// List of supported destructors
    internal enum Destructor {
        /// Special value for memory destructors, which indicates that the content pointer is constant and will never change.
        static let `static` = unsafeBitCast(OpaquePointer(bitPattern: 0), to: sqlite3_destructor_type.self)
        /// Special value for memory destructors, which indicates that the content will likely change in the near future and the SQLite should make its own private copy of the content before returning.
        static let transient = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
    }
}

extension SQLite.Result {
    /// Dictionary of low-level primary result codes.
    static let primary: [Int32:(name: String, details: String)] = [
        SQLITE_OK         : ("SQLITE_OK",         "Successful result"),
        SQLITE_ERROR      : ("SQLITE_ERROR",      "Generic error"),
        SQLITE_INTERNAL   : ("SQLITE_INTERNAL",   "Internal logic error in SQLite"),             // Not supported
        SQLITE_PERM       : ("SQLITE_PERM",       "Access permission denied"),
        SQLITE_ABORT      : ("SQLITE_ABORT",      "Callback routine requested an abort"),
        SQLITE_BUSY       : ("SQLITE_BUSY",       "The database file is locked"),
        SQLITE_LOCKED     : ("SQLITE_LOCKED",     "A table in the database is locked"),
        SQLITE_NOMEM      : ("SQLITE_NOMEM",      "A malloc() failed"),
        SQLITE_READONLY   : ("SQLITE_READONLY",   "Attempt to write a readonly database"),
        SQLITE_INTERRUPT  : ("SQLITE_INTERRUPT",  "Operation terminated by sqlite3_interr"),
        SQLITE_IOERR      : ("SQLITE_IOERR",      "Some kind of disk I/O error occurred"),
        SQLITE_CORRUPT    : ("SQLITE_CORRUPT",    "The database disk image is malformed"),
        SQLITE_NOTFOUND   : ("SQLITE_NOTFOUND",   "Unknown opcode in sqlite3_file_control("),
        SQLITE_FULL       : ("SQLITE_FULL",       "Insertion failed because database is full"),
        SQLITE_CANTOPEN   : ("SQLITE_CANTOPEN",   "Unable to open the database file"),
        SQLITE_PROTOCOL   : ("SQLITE_PROTOCOL",   "Database lock protocol error"),
        SQLITE_EMPTY      : ("SQLITE_EMPTY",      "Internal use only"),                          // Not supported
        SQLITE_SCHEMA     : ("SQLITE_SCHEMA",     "The database schema changed"),
        SQLITE_TOOBIG     : ("SQLITE_TOOBIG",     "String or BLOB exceeds size limit"),
        SQLITE_CONSTRAINT : ("SQLITE_CONSTRAINT", "Abort due to constraint violation"),
        SQLITE_MISMATCH   : ("SQLITE_MISMATCH",   "Data type mismatch"),
        SQLITE_MISUSE     : ("SQLITE_MISUSE",     "Library used incorrectly"),
        SQLITE_NOLFS      : ("SQLITE_NOLFS",      "Uses OS features not supported on host"),     // Not supported
        SQLITE_AUTH       : ("SQLITE_AUTH",       "Authorization denied"),
        SQLITE_FORMAT     : ("SQLITE_FORMAT",     "Not used"),                                   // Not supported
        SQLITE_RANGE      : ("SQLITE_RANGE",      "2nd parameter to sqlite3_bind out of range"),
        SQLITE_NOTADB     : ("SQLITE_NOTADB",     "File opened that is not a database file"),
        SQLITE_NOTICE     : ("SQLITE_NOTICE",     "Notifications from sqlite3_log()"),
        SQLITE_WARNING    : ("SQLITE_WARNING",    "Warnings from sqlite3_log()"),
        SQLITE_ROW        : ("SQLITE_ROW",        "sqlite3_step() has another row ready"),
        SQLITE_DONE       : ("SQLITE_DONE",       "sqlite3_step() has finished executing")
    ]
    
    /// Dictionary of low-level extended result codes.
    static let extended: [Int32:(name: String, details: String)] = [
        SQLITE_IOERR |  1<<8      : ("SQLITE_IOERR_READ",              "disk I/O error"),
        SQLITE_IOERR |  2<<8      : ("SQLITE_IOERR_SHORT_READ",        "disk I/O error"),
        SQLITE_IOERR |  3<<8      : ("SQLITE_IOERR_WRITE",             "disk I/O error"),
        SQLITE_IOERR |  4<<8      : ("SQLITE_IOERR_FSYNC",             "disk I/O error"),
        SQLITE_IOERR |  5<<8      : ("SQLITE_IOERR_DIR_FSYNC",         "disk I/O error"),
        SQLITE_IOERR |  6<<8      : ("SQLITE_IOERR_TRUNCATE",          "disk I/O error"),
        SQLITE_IOERR |  7<<8      : ("SQLITE_IOERR_FSTAT",             "disk I/O error"),
        SQLITE_IOERR |  8<<8      : ("SQLITE_IOERR_UNLOCK",            "disk I/O error"),
        SQLITE_IOERR |  9<<8      : ("SQLITE_IOERR_RDLOCK",            "disk I/O error"),
        SQLITE_IOERR | 10<<8      : ("SQLITE_IOERR_DELETE",            "disk I/O error"),
        SQLITE_IOERR | 11<<8      : ("SQLITE_IOERR_BLOCKED",           "disk I/O error"),
        SQLITE_IOERR | 12<<8      : ("SQLITE_IOERR_NOMEM",             "disk I/O error"),
        SQLITE_IOERR | 13<<8      : ("SQLITE_IOERR_ACCESS",            "disk I/O error"),
        SQLITE_IOERR | 14<<8      : ("SQLITE_IOERR_CHECKRESERVEDLOCK", "disk I/O error"),
        SQLITE_IOERR | 15<<8      : ("SQLITE_IOERR_LOCK",              "disk I/O error"),
        SQLITE_IOERR | 16<<8      : ("SQLITE_IOERR_CLOSE",             "disk I/O error"),
        SQLITE_IOERR | 17<<8      : ("SQLITE_IOERR_DIR_CLOSE",         "disk I/O error"),
        SQLITE_IOERR | 18<<8      : ("SQLITE_IOERR_SHMOPEN",           "disk I/O error"),
        SQLITE_IOERR | 19<<8      : ("SQLITE_IOERR_SHMSIZE",           "disk I/O error"),
        SQLITE_IOERR | 20<<8      : ("SQLITE_IOERR_SHMLOCK",           "disk I/O error"),
        SQLITE_IOERR | 21<<8      : ("SQLITE_IOERR_SHMMAP",            "disk I/O error"),
        SQLITE_IOERR | 22<<8      : ("SQLITE_IOERR_SEEK",              "disk I/O error"),
        SQLITE_IOERR | 23<<8      : ("SQLITE_IOERR_DELETE_NOENT",      "disk I/O error"),
        SQLITE_IOERR | 24<<8      : ("SQLITE_IOERR_MMAP",              "disk I/O error"),
        SQLITE_IOERR | 25<<8      : ("SQLITE_IOERR_GETTEMPPATH",       "disk I/O error"),
        SQLITE_IOERR | 26<<8      : ("SQLITE_IOERR_CONVPATH",          "disk I/O error"),
        SQLITE_IOERR | 27<<8      : ("SQLITE_IOERR_VNODE",             "disk I/O error"),
        SQLITE_IOERR | 28<<8      : ("SQLITE_IOERR_AUTH",              "disk I/O error"),
        SQLITE_LOCKED |  1<<8     : ("SQLITE_LOCKED_SHAREDCACHE",      "database table is locked"),
        SQLITE_BUSY |  1<<8       : ("SQLITE_BUSY_RECOVERY",           "database is locked"),
        SQLITE_BUSY |  2<<8       : ("SQLITE_BUSY_SNAPSHOT",           "database is locked"),
        SQLITE_CANTOPEN |  1<<8   : ("SQLITE_CANTOPEN_NOTEMPDIR",      "unable to open database file"),
        SQLITE_CANTOPEN |  2<<8   : ("SQLITE_CANTOPEN_ISDIR",          "unable to open database file"),
        SQLITE_CANTOPEN |  3<<8   : ("SQLITE_CANTOPEN_FULLPATH",       "unable to open database file"),
        SQLITE_CANTOPEN |  4<<8   : ("SQLITE_CANTOPEN_CONVPATH",       "unable to open database file"),
        SQLITE_CORRUPT |  1<<8    : ("SQLITE_CORRUPT_VTAB",            "database disk image is malformed"),
        SQLITE_READONLY |  1<<8   : ("SQLITE_READONLY_RECOVERY",       "attempt to write a readonly database"),
        SQLITE_READONLY |  2<<8   : ("SQLITE_READONLY_CANTLOCK",       "attempt to write a readonly database"),
        SQLITE_READONLY |  3<<8   : ("SQLITE_READONLY_ROLLBACK",       "attempt to write a readonly database"),
        SQLITE_READONLY |  4<<8   : ("SQLITE_READONLY_DBMOVED",        "attempt to write a readonly database"),
        SQLITE_ABORT |  2<<8      : ("SQLITE_ABORT_ROLLBACK",          "abort due to ROLLBACK"),
        SQLITE_CONSTRAINT |  1<<8 : ("SQLITE_CONSTRAINT_CHECK",        "constraint failed"),
        SQLITE_CONSTRAINT |  2<<8 : ("SQLITE_CONSTRAINT_COMMITHOOK",   "constraint failed"),
        SQLITE_CONSTRAINT |  3<<8 : ("SQLITE_CONSTRAINT_FOREIGNKEY",   "constraint failed"),
        SQLITE_CONSTRAINT |  4<<8 : ("SQLITE_CONSTRAINT_FUNCTION",     "constraint failed"),
        SQLITE_CONSTRAINT |  5<<8 : ("SQLITE_CONSTRAINT_NOTNULL",      "constraint failed"),
        SQLITE_CONSTRAINT |  6<<8 : ("SQLITE_CONSTRAINT_PRIMARYKEY",   "constraint failed"),
        SQLITE_CONSTRAINT |  7<<8 : ("SQLITE_CONSTRAINT_TRIGGER",      "constraint failed"),
        SQLITE_CONSTRAINT |  8<<8 : ("SQLITE_CONSTRAINT_UNIQUE",       "constraint failed"),
        SQLITE_CONSTRAINT |  9<<8 : ("SQLITE_CONSTRAINT_VTAB",         "constraint failed"),
        SQLITE_CONSTRAINT | 10<<8 : ("SQLITE_CONSTRAINT_ROWID",        "constraint failed"),
        SQLITE_NOTICE |  1<<8     : ("SQLITE_NOTICE_RECOVER_WAL",      "notification message"),
        SQLITE_NOTICE |  2<<8     : ("SQLITE_NOTICE_RECOVER_ROLLBACK", "notification message"),
        SQLITE_WARNING |  1<<8    : ("SQLITE_WARNING_AUTOINDEX",       "warning message"),
        SQLITE_AUTH |  1<<8       : ("SQLITE_AUTH_USER",               "authorization denied"),
        SQLITE_OK |  1<<8         : ("SQLITE_OK_LOAD_PERMANENTLY",     "not an error")
    ]
}
