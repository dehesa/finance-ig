import Foundation

public struct UnfairLock {
    /// The low-level unfair lock.
    @usableFromInline internal let _lock: UnsafeMutablePointer<os_unfair_lock>
    /// Designated initializer.
    @_transparent public init() {
        self._lock = .allocate(capacity: 1)
        self._lock.initialize(to: os_unfair_lock())
    }
    
    /// Locks the receiving unfair lock.
    @_transparent public func lock() {
        os_unfair_lock_lock(self._lock)
    }
    
    /// Unlocks the receiving unfair lock.
    @_transparent public func unlock() {
        os_unfair_lock_unlock(self._lock)
    }
    
    /// Executes a priviledge operation on the receiving lock.
    /// - parameter closure: The operation to execute while holding the closure.
    /// - returns: The value returned from the closure.
    @discardableResult @_transparent @inline(__always) public func execute<T>(within closure: ()->T) -> T {
        os_unfair_lock_lock(self._lock)
        let result = closure()
        os_unfair_lock_unlock(self._lock)
        return result
    }
    
    /// It deinitializes and deallocate the low-level unfair lock.
    /// - warning: This operation shall only be called once.
    @_transparent public func invalidate() {
        self._lock.deinitialize(count: 1)
        self._lock.deallocate()
    }
}
