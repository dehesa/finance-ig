import Foundation
import ReactiveSwift
@testable import IG

extension SignalProducer where Error==API.Error {
    /// Convenience function that creates a weak bond with the API instance and every time is executed/started, checks whether the instance is still there; if so, it proceeds; if not, it generates an error.
    /// - parameter api: The API instance containing the URL Session. A weak bond is created.
    /// - parameter strategy: Signal flatmap strategy to be used to concatenate the call.
    /// - parameter next: The endpoint to be called on a successful value from the receiving signal.
    public func call<V>(on api: API, strategy: FlattenStrategy = .latest, _ next: @escaping (API,Value)->SignalProducer<V,API.Error>) -> SignalProducer<V,API.Error> {
        return self.flatMap(strategy) { [weak api] (receivedValue) -> SignalProducer<V,API.Error> in
            guard let api = api else { return SignalProducer<V,API.Error>(error: .sessionExpired) }
            return next(api, receivedValue)
        }
    }
}
