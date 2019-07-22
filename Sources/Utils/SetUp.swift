import Foundation

internal protocol SetUp {}

extension SetUp where Self: Any {
    /// Makes the receiving value accessible within the passed block parameter.
    /// - parameter block: Closure executing a given task on the receiving function value.
    internal func setUp(with block: (Self)->Void) {
        block(self)
    }
    
    /// Makes the receiving value accessible within the passed block parameter and ends up returning the modified value.
    /// - parameter block: Closure executing a given task on the receiving function value.
    /// - returns: The modified value
    internal func set(with block: (inout Self) throws -> Void) rethrows -> Self {
        var copy = self
        try block(&copy)
        return copy
    }
}

extension URLRequest: SetUp {}
extension JSONDecoder: SetUp {}
extension DateComponents: SetUp {}

extension NSObject: SetUp {}
