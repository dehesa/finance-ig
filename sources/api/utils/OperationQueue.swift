import Foundation

internal extension OperationQueue {
    /// Convenience initializer for a simple operation queue.
    /// - parameter name: The given queue name.
    /// - parameter maxConcurrentOperationCount: Maximum concurrent operations.
    /// - parameter queue: Underlying  `DispatchQueue`.
    /// - parameter startSuspended: Booleain indicating whether the queue starts suspended.
    convenience init(underlying queue: DispatchQueue, maxConcurrentOperationCount: Int = OperationQueue.defaultMaxConcurrentOperationCount, startSuspended: Bool = false) {
        self.init()
        self.name = queue.label + ".operations"
        self.qualityOfService = Self._map(qos: queue.qos)
        self.maxConcurrentOperationCount = maxConcurrentOperationCount
        self.underlyingQueue = queue
        self.isSuspended = startSuspended
    }
    
    /// Transforms a `DispatchQueue` quality of service into an `OperationQueue` quality of service.
    /// - parameter qos: The `DispatchQueue` relative quality of service.
    private static func _map(qos: DispatchQoS) -> QualityOfService {
        let priority = qos.relativePriority
        
        if priority >= DispatchQoS.userInteractive.relativePriority {
            return .userInteractive
        } else if priority >= DispatchQoS.userInitiated.relativePriority {
            return .userInitiated
        } else if priority >= DispatchQoS.default.relativePriority {
            return .default
        } else if priority >= DispatchQoS.utility.relativePriority {
            return .utility
        } else {
            return .background
        }
    }
}
