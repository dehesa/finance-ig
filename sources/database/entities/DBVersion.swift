internal extension Database {
    /// The number of versions currently supported
    enum Version: Int, Comparable, CaseIterable {
        /// The version for database creation.
        case v0 = 0
        /// The initial version.
        case v1 = 1
        /// DB changed price dates to integer numbers.
        case v2 = 2
        /// DB added the interest rate table.
        case v3 = 3
        
        /// The last described migration.
        static var latest: Self { Self.allCases.last! }
        
        /// Returns the next version from the current version.
        var next: Self? { Self(rawValue: self.rawValue + 1) }
        
        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }
}

internal extension Database {
    /// Application identifier "magic" number used to identify SQLite database files.
    static let applicationId: Int32 = 840797404
}
