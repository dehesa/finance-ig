import Foundation

extension OperationQueue {
    /// Convenience initializer for a simple operation queue.
    /// - parameter name: The given queue name.
    /// - parameter maxConcurrentOperationCount: Maximum concurrent operations.
    /// - parameter underlyingQueue: Underlying  `DispatchQueue`.
    /// - parameter startSuspended: Booleain indicating whether the queue starts suspended.
    convenience init(name: String, maxConcurrentOperationCount: Int = OperationQueue.defaultMaxConcurrentOperationCount, underlyingQueue: DispatchQueue, startSuspended: Bool = false) {
        self.init()
        self.qualityOfService = Self.qos(of: underlyingQueue)
        self.maxConcurrentOperationCount = maxConcurrentOperationCount
        self.underlyingQueue = underlyingQueue
        self.name = name
        self.isSuspended = startSuspended
    }
    
    private static func qos(of queue: DispatchQueue) -> QualityOfService {
        let priority = queue.qos.relativePriority
        
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
