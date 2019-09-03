import Foundation

infix operator ?!

/// Checks whether the value exists. If so, it returns it; if not, it throws the given error.
/// - parameter lhs: Optional value to check for existance.
/// - parameter rhs: Swift error to throw in case of no value.
/// - returns: The value (non-optional) passed as parameter.
/// - throws: The Swift error returned on the right hand-side autoclosure.
internal func ?!<T>(lhs: T?, rhs: @autoclosure ()->Swift.Error) throws -> T {
    guard let result = lhs else { throw rhs() }
    return result
}

// MARK: - Sets

infix operator ∩ : ComparisonPrecedence

/// Performs an intersection between the `lhs` and the `rhs` sets.
public func ∩ <T>(lhs: Set<T>, rhs: Set<T>) -> Set<T> {
    return lhs.intersection(rhs)
}

infix operator ∪ : ComparisonPrecedence

/// Performs a union between the `lhs` and the `rhs` sets.
public func ∪ <T>(lhs: Set<T>, rhs: Set<T>) -> Set<T> {
    return lhs.union(rhs)
}