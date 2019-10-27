import Combine

extension IG.DB {
    /// Domain namespace retaining anything related to DB requests.
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

extension IG.DB {
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
