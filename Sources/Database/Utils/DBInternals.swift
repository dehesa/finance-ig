import Combine

extension IG.DB {
    /// Domain namespace retaining anything related to DB requests.
    public enum Request {}
    
    /// Type erased `Combine.Future` where a single value and a completion or a failure will be sent.
    /// This behavior is guaranteed when you see this type.
    public typealias DiscretePublisher<T> = AnyPublisher<T,IG.DB.Error>
    /// Publisher that can send zero, one, or many values followed by a successful completion.
    public typealias ContinuousPublisher<T> = AnyPublisher<T,IG.DB.Error>
}

extension IG.DB {
    /// Publisher output types.
    internal enum Output {
        /// DB pipeline's first stage variables: the DB instance to use and some computed values (or `Void`).
        internal typealias Instance<T> = (database: IG.DB, values: T)
    }
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
