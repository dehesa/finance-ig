import Foundation

extension IG.DB {
    /// Domain namespace retaining anything related to DB requests.
    public enum Request {}
    /// Domain namespace retaining anything related to DB responses.
    public enum Response<T> {
        case success(T)
        case failure(IG.DB.Error)
        case interruption
        case expired
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
