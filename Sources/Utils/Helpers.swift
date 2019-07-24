import Foundation

extension DispatchQoS {
    /// Quality of Service for real time messaging.
    internal static let realTimeMessaging = DispatchQoS(qosClass: .userInitiated, relativePriority: 0)
}

infix operator ?!

/// Checks whether the value exists. If so, it returns it; if not, it throws the given error.
/// - parameter lhs: Optional value to check for existance.
/// - parameter rhs: Swift error to throw in case of no value.
/// - returns: The value (non-optional) passed as parameter.
/// - throws: The Swift error passed as parameter.
internal func ?!<T>(lhs: T?, rhs: Swift.Error) throws -> T {
    guard let result = lhs else { throw rhs }
    return result
}

extension Array where Element: Equatable {
    /// Removes the duplicate elements while conserving order.
    internal var uniqueElements: Self {
        return self.reduce(into: Self.init()) { (result, element) in
            guard !result.contains(element) else { return }
            result.append(element)
        }
    }
}
