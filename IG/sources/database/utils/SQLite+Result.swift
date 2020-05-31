import Foundation
import SQLite3

extension SQLite {
    /// A result code retrieve from a low-level SQLite routine.
    internal struct Result: RawRepresentable, Equatable, CustomStringConvertible {
        private(set) var rawValue: Int32
        
        init?(rawValue: Int32) {
            guard Self.primary[rawValue] != nil || Self.extended[rawValue] != nil else { return nil }
            self.init(trusted: rawValue)
        }
        
        /// Designated initializer trusting the given value.
        fileprivate init(trusted rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        // Returns the constant name of the result code.
        var name: String? {
            Self.primary[self.rawValue]?.name ?? Self.extended[self.rawValue]?.name
        }
        
        var description: String {
            let pointer = sqlite3_errstr(self.rawValue) ?! fatalError("The receiving result '\(self.rawValue)' is not an SQLite result")
            return .init(cString: pointer)
        }
        
        /// Returns a more verbose explanation of the error.
        var verbose: String? {
            return Self.primary[self.rawValue]?.details ??
                   Self.extended[self.rawValue]?.details
        }
    }
}

extension SQLite.Result {
    /// Booleain indicating whether the receiving result is "just" a primary result or it is a extended result.
    var isPrimary: Bool {
        self.rawValue >> 8 == 0
    }
    /// Boolean indicating whether the result code is in the extended error category.
    var isExtended: Bool {
        self.rawValue >> 8 > 0
    }
    /// Returns the primary result of the given result.
    ///
    /// If the result is already primary, it returns itself.
    var primary: Self {
        .init(trusted: self.rawValue & 0xFF)
    }
    /// Boolean indicating whether the receiving result is from the category/primary of any of the given as argument.
    /// - parameter primaries: Primary results that the receiving result may be related to.
    func relates(to primaries: Self...) -> Bool {
        let value = self.rawValue & 0xFF
        for primary in primaries where primary.rawValue == value {
            return true
        }
        return false
    }
    
    /// Returns `true` if the code on the left matches the code on the right.
    public static func ~= (pattern: Self, code: Self) -> Bool {
        pattern.rawValue == code.rawValue
    }
    
    /// Returns `true` if the code on the left matches the code on the right.
    public static func ~= (pattern: Self, code: Int32) -> Bool {
        pattern.rawValue == code
    }
    
    /// Returns `true` if the code on the left matches the code on the right.
    public static func ~= (pattern: Int32, code: Self) -> Bool {
        code.rawValue == pattern
    }
}

extension Int32 {
    /// Returns the result representation of an SQLite result.
    /// - precondition: This function expect the value to be a correct SQLite result. No conditions are performed.
    var result: SQLite.Result {
        .init(trusted: self)
    }
    /// Checks that the receiving integer is equal to `value`; if so, `nil` is returned. Otherwise, returns the receiving value wrapped as a result.
    func enforce(_ value: SQLite.Result) -> SQLite.Result? {
        guard self == value.rawValue else { return .init(trusted: self) }
        return nil
    }
    /// Expects the reeiving integer is equal to `value`; if not, the error in the closure is thrown.
    func expects(_ value: SQLite.Result, _ error: (_ receivedCode: SQLite.Result) -> Database.Error = { .callFailed(.execCommand, code: $0) }) throws {
        if self == value.rawValue { return }
        throw error(.init(trusted: self))
    }
    
    static func == (lhs: Self, rhs: SQLite.Result) -> Bool {
        lhs == rhs.rawValue
    }
    
    static func == (lhs: SQLite.Result, rhs: Self) -> Bool {
        lhs.rawValue == rhs
    }
}


extension SQLite.Result {
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
