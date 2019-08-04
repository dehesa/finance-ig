import ReactiveSwift
import Foundation

extension Signal where Value==Void, Error==Never {
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

extension Signal {
    /// Forwards any event from the receiving signal, but if the receiving signal is not terminated by `interval` seconds, an error is sent downstream.
    /// - parameter `interval`: The number of seconds to wait for.
    /// - parameter ` scheduler`: The scheduler where the error will be generated.
    /// - parameter ` errorGenerator`: The error generated if the amount of time elapse.
    /// - precondition: `interval` must be a valid number greater than or equal to zero.
    /// - returns: Signal forwarding all receiving signal events.
    internal func timeout(after interval: TimeInterval, on scheduler: DateScheduler, generating errorGenerator: @escaping ()->Error) -> Signal<Value,Error> {
        precondition(!interval.isNaN && interval >= 0)
        
        return Signal { (generator, lifetime) in
            let date = scheduler.currentDate.addingTimeInterval(interval)
            
            lifetime += scheduler.schedule(after: date) {
                generator.send(error: errorGenerator())
            }
            
            lifetime += self.observe(generator)
        }
    }
}

extension Signal where Error == Never {
    /// Forwards any event from the receiving signal, but if the receiving signal is not terminated by `interval` seconds, an error is sent downstream.
    /// - parameter `interval`: The number of seconds to wait for.
    /// - parameter ` scheduler`: The scheduler where the error will be generated.
    /// - parameter ` errorGenerator`: The error generated if the amount of time elapse.
    /// - precondition: `interval` must be a valid number greater than or equal to zero.
    /// - returns: Signal forwarding all receiving signal events.
    internal func timeout<NewError>(after interval: TimeInterval, on scheduler: DateScheduler, generating errorGenerator: @escaping ()->NewError) -> Signal<Value,NewError> {
        return self.promoteError(NewError.self)
            .timeout(after: interval, on: scheduler, generating: errorGenerator)
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
