import Combine
import Foundation

/// Publisher which will execute the given closure once per pipeline activation (then the closure is deleted).
///
/// The closure receives a `PassthroughSubject` which can be used to send information downstream.
/// There is no need to keep a reference to the closure since it is kept by the inner subscription.
/// - note: The closure will be executed when the shadow subscription chain has been activated and the first non-zero deman has been requested.
internal struct PassthroughPublisher<Output,Failure:Error>: Publisher {
    /// The closure type being store for delated execution.
    typealias Closure = (PassthroughSubject<Output,Failure>) -> Void
    /// Publisher's closure storage.
    ///
    /// - note: The closure is kept in the publisher, thus if you keep the publisher around any reference in the closure will be kept too.
    private let closure: Closure
    /// Designated initializer.
    /// - parameter closure: The closure for delayed execution.
    init(_ setup: @escaping Closure) {
        self.closure = setup
    }
    
    func receive<S>(subscriber: S) where S:Subscriber, Failure==S.Failure, Output==S.Input {
        let subject = PassthroughSubject<Output,Failure>()
        let subscription = Conduit(subject: subject, downstream: subscriber, closure: self.closure)
        subject.subscribe(subscription)
    }
    
    /// Internal Shadow subscription catching all messages from downstream and forwarding them upstream.
    private final class Conduit<Downstream>: Subscription, Subscriber where Downstream: Subscriber, Failure==Downstream.Failure, Output==Downstream.Input {
        /// The Conduit acts as the origin of a shadow subscription change, but in reality it has a `PassthroughSubject` above it.
        var upstream: (subject: PassthroughSubject<Output,Failure>, subscription: Subscription?)?
        /// Any `Subscription/Subscriber` down the shadow subscription chain.
        private var downstream: Downstream?
        /// The closure to execute once the first data is requested. Then it is deleted.
        private var closure: Closure?
        /// Designated initializer passing all the needed info (except the upstream subscription).
        init(subject: PassthroughSubject<Output,Failure>, downstream: Downstream, closure: @escaping Closure) {
            self.downstream = downstream
            self.upstream = (subject, nil)
            self.closure = closure
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard let upstream = self.upstream else { return }
            upstream.subscription!.request(demand)
            
            guard let closure = self.closure, demand > .none else { return }
            self.closure = nil
            closure(upstream.subject)
        }
        
        func cancel() {
            self.closure = nil
            self.downstream = nil
            if let upstream = self.upstream {
                upstream.subscription?.cancel()
                self.upstream = nil
            }
        }
        
        func receive(subscription: Subscription) {
            guard let _ = self.upstream,
                  let downstream = self.downstream else {
                return self.cancel()
            }
            self.upstream?.subscription = subscription
            downstream.receive(subscription: self)
        }
        
        func receive(_ input: Output) -> Subscribers.Demand {
            guard let downstream = self.downstream else {
                self.cancel(); return .none
            }
            return downstream.receive(input)
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            self.closure = nil
            if let downstream = downstream {
                self.downstream = nil
                downstream.receive(completion: completion)
            }
            self.upstream = nil
        }
    }
}
