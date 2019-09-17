import Foundation

extension IG.DB {
    /// Domain namespace retaining anything related to DB requests.
    public enum Request {}
    /// Domain namespace retaining anything related to DB responses.
    internal enum Response<T> {
        case success(value: T)
        case failure(error: IG.DB.Error)
        case interruption
        case expired
    }
}

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

// MARK: - Request types

extension IG.DB.Request {
    /// Indication of whether an operation should continue or stop.
    internal enum Iteration: Equatable {
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
    internal typealias Expiration = () -> Self.Iteration
}
