import Combine

extension Database {
    /// Domain namespace retaining anything related to Database requests.
    public enum Request {}
}

/// Protocol for all types that can be represented through a SQL table.
internal protocol DBTable {
    /// The table name for the latest version.
    static var tableName: String { get }
    /// Returns a SQL definition for the receiving type.
    static var tableDefinition: String { get }
}

// MARK: - Constants

extension Database {
    /// Measurement units are usually in pips or as percentage.
    public enum Unit: Int, CustomDebugStringConvertible {
        case points = 0
        case percentage = 1
        
        public var debugDescription: String {
            switch self {
            case .points:     return "points"
            case .percentage: return "%"
            }
        }
    }
}

// MARK: - Conveniences

extension Bool {
    /// Returns a Boolean from a SQLite value.
    internal init(_ value: Int32) {
        self = value > 0
    }
}

extension Int32 {
    /// Returns the SQLite value for a boolean.
    internal init(_ value: Bool) {
        self = value ? 1 : 0
    }
}

