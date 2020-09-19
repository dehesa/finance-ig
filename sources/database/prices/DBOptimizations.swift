import SQLite3

extension Database {
    /// Rebuilds and repacks the underlying database for better performance.
    public func rebuild() throws {
        try self.channel.unrestrictedAccess { (database) in
            try sqlite3_exec(database, "VACUUM", nil, nil, nil).expects(.ok) {
                IG.Error._vacuumFailed(code: $0)
            }
        }
    }
    
    /// Fast optimize the underlying database for better performance.
    public func optimize() throws {
        try self.channel.unrestrictedAccess { (database) in
            try sqlite3_exec(database, "PRAGMA optimize", nil, nil, nil).expects(.ok) {
                IG.Error._optimizeFailed(code: $0)
            }
        }
    }
}

private extension IG.Error {
    /// Error raised when the VACUUM/rebuild command failed to completed.
    static func _vacuumFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "The VACUUM statement failed.", help: "Review the error code and contact the repo maintainer.", info: ["Error code": code])
    }
    /// Error raised when the simple optimization call failed.
    static func _optimizeFailed(code: SQLite.Result) -> Self {
        Self(.database(.callFailed), "The SQLite optimization failed.", help: "Review the error code and contact the repo maintainer.", info: ["Error code": code])
    }
}
