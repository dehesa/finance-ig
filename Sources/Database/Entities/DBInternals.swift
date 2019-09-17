import Foundation

extension IG.DB {
    /// Domain namespace retaining anything related to DB requests.
    public enum Request {}
    /// Domain namespace retaining anything related to DB responses.
    internal enum Response {}
}

// MARK: Request Types

extension IG.DB.Request {
    /// Indication of whether an operation should continue or stop.
    internal enum Step: Equatable {
        /// The operation shall continue.
        case `continue`
        /// The operation shall stop as soon as possible.
        case stop
        
        /// Boolean indicating whether the following iteration is allowed.
        var isAllowed: Bool {
            return self == .continue
        }
    }
    
    /// Closure asking for next iteration permission.
    /// - returns: Akind to a Boolean value indicating whether the routine is allowed to continue or it should stop.
    internal typealias Permission = () -> Self.Step
}

// MARK: Response Types

extension IG.DB.Response {
    ///
    internal enum Step<T> {
        case success(T)
        case failure(IG.DB.Error)
        case interruption
        case expired
    }
}

// MARK: - Supporting Types

/// Protocol for all types that can be represented through a SQL table.
internal protocol DBTable {
    /// The table name for the latest version.
    static var tableName: String { get }
    /// Returns a SQL definition for the receiving type.
    static var tableDefinition: String { get }
}

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
