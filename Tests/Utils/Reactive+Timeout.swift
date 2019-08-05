import ReactiveSwift
import Foundation

extension SignalProducer where Value==Void, Error==Never {
    /// When producer is started a single complete event shall be sent after the time interval has elapsed.
    /// - parameter `interval`: The number of seconds to wait for.
    /// - parameter ` scheduler`: The scheduler where the complete event will be generated.
    internal static func empty(after interval: TimeInterval, on scheduler: DateScheduler) -> Self {
        precondition(!interval.isNaN && interval >= 0)
        
        return Self.init { (generator, lifetime) in
            let date = scheduler.currentDate.addingTimeInterval(interval)
            
            lifetime += scheduler.schedule(after: date) {
                generator.sendCompleted()
            }
        }
    }
}

extension SignalProducer {
    /// Forward events from `self` until `interval`. Then if producer isn't completed yet, fails with `error` on `scheduler`.
    /// - note: If the interval is 0, the timeout will be scheduled immediately. The producer must complete synchronously (or on a faster scheduler) to avoid the timeout.
    /// - parameter interval: Number of seconds to wait for `self` to complete.
    /// - parameter error: Error to send with `failed` event if `self` is not completed when `interval` passes.
    /// - parameter scheduler: A scheduler to deliver error on.
    /// - returns: A producer that sends events for at most `interval` seconds, then, if not `completed` - sends `error` with `failed` event on `scheduler`.
    internal func timeout(after interval: TimeInterval, on queue: DateScheduler, raising error: @escaping ([Value])->Error) -> SignalProducer {
        var values: [Value] = []
        return self.on(value: { values.append($0) }).timeout(after: interval, raising: error(values), on: queue)
    }
}

extension QueueScheduler {
    /// Generates a `QueueScheduler` with the given properties.
    /// - parameter qos: The *Quality of Service* for the Dispatch Queue.
    /// - parameter suffix: The suffix to be appended on the Dispatch Queue label. If `nil`, the suffix `random.queue.##` will be appended to the bundle's identifier (`##` being a random number between 0 and 10,000).
    /// - parameter targetQueue: The parent queue of the created Dispatch Queue.
    internal convenience init(qos: DispatchQoS = .default, suffix: String?, targeting targetQueue: DispatchQueue? = nil) {
        var name = Bundle.init(for: UselessClass.self).bundleIdentifier!
        if let suffix = suffix {
            if !suffix.hasPrefix(".") {
                name.append(".")
            }
            name.append(suffix)
        } else {
            let number = Int.random(in: 0...10000)
            name.append("random.queue.\(number)")
        }
        self.init(qos: qos, name: name, targeting: targetQueue)
    }
}

fileprivate final class UselessClass {}
