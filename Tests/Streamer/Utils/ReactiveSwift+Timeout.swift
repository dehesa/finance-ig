import ReactiveSwift
import Foundation

extension Signal {
    func timeout(after interval: TimeInterval, on scheduler: DateScheduler, generating errorGenerator: @escaping ()->Error) -> Signal<Value, Error> {
        precondition(interval >= 0)
        return Signal { observer, lifetime in
            let date = scheduler.currentDate.addingTimeInterval(interval)
            
            lifetime += scheduler.schedule(after: date) {
                observer.send(error: errorGenerator())
            }
            
            lifetime += self.observe(observer)
        }
    }
}

extension Signal where Error == Never {
    func timeout<NewError>(after interval: TimeInterval, on scheduler: DateScheduler, generating errorGenerator: @escaping ()->NewError) -> Signal<Value, NewError> {
        return self.promoteError(NewError.self)
            .timeout(after: interval, on: scheduler, generating: errorGenerator)
    }
}

extension SignalProducer where Value==Void, Error==Never {
    /// When producer is started a single complete event shall be sent after the time interval has elapsed.
    static func empty(after interval: TimeInterval, on scheduler: DateScheduler) -> Self {
        precondition(interval >= 0)
        
        return Self.init { (generator, lifetime) in
            let date = scheduler.currentDate.addingTimeInterval(interval)
            
            lifetime += scheduler.schedule(after: date) {
                generator.sendCompleted()
            }
        }
    }
}

extension QueueScheduler {
    /// Generates a `QueueScheduler` with the given properties.
    convenience init(qos: DispatchQoS = .default, suffix: String?, targeting targetQueue: DispatchQueue? = nil) {
        var name = Bundle.init(for: UselessClass.self).bundleIdentifier!
        if let suffix = suffix {
            if !suffix.hasPrefix(".") {
                name.append(".")
            }
            name.append(suffix)
        } else {
            let number = Int.random(in: 0...1000)
            name.append("random.queue.\(number)")
        }
        self.init(qos: qos, name: name, targeting: targetQueue)
    }
}

fileprivate final class UselessClass {}
