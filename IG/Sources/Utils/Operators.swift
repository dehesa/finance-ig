// MARK: - Optionals

infix operator ?!

extension Optional {
    /// Checks whether the value exists. If so, it returns it; if not, it throws the given error.
    /// - parameter lhs: Optional value to check for existance.
    /// - parameter rhs: Swift error to throw in case of no value.
    /// - returns: The value (non-optional) passed as parameter.
    /// - throws: The Swift error returned on the right hand-side autoclosure.
    internal static func ?!(lhs: Self, rhs: @autoclosure ()->Swift.Error) throws -> Wrapped {
        switch lhs {
        case .some(let v): return v
        case .none: throw rhs()
        }
    }
    
    /// Unwraps the receiving optional and execute the appropriate closure depending on whether the value is `.none` or `.some`.
    @discardableResult
    internal func unwrap<T>(none: ()->T, `some`: (_ wrapped: Wrapped)->T) -> T {
        switch self {
        case .some(let v): return some(v)
        case .none: return none()
        }
    }
}

// MARK: - Set Up

internal protocol SettableValue {}
internal protocol SettableReference: class {}

extension SettableValue {
    /// Makes the receiving value accessible within the passed block parameter and ends up returning the modified value.
    /// - parameter block: Closure executing a given task on the receiving function value.
    /// - returns: The modified value.
    internal func set(with block: (inout Self) throws -> Void) rethrows -> Self {
        var copy = self
        try block(&copy)
        return copy
    }
}

extension SettableReference {
    /// Makes the receiving reference accessible within the argument closure so it can be tweaked, before returning it again.
    /// - parameter block: Closure executing a given task on the receiving function value.
    /// - returns: The pre-set reference.
    @discardableResult
    internal func set(with block: (Self) throws -> Void) rethrows -> Self {
        try block(self)
        return self
    }
}

// MARK: Compliers

extension Calendar: SettableValue {}
extension DateComponents: SettableValue {}
extension URLRequest: SettableValue {}
extension IG.API.Error: SettableValue {}

extension DateFormatter: SettableReference {}
extension JSONDecoder: SettableReference {}