import Combine
import Foundation

extension Publisher {
    /// Subscriber waiting for a single value followed immediatelly by a successful completion.
    ///
    /// If the expectation are not fulfilled, the an error is raised or `nil` is returned if the publisher successfully finished, but no value was emitted.
    /// - parameter handler: Returns the result of the publisher.
    @discardableResult
    func result(_ handler: @escaping (Result<Output,Failure>?)->Void) -> AnyCancellable? {
        var result: Output? = nil
        var cancellable: AnyCancellable? = nil
        
        cancellable = self.sink(receiveCompletion: {
            switch $0 {
            case .failure(let error):
                handler(.failure(error))
            case .finished where result != nil:
                handler(.success(result!))
            case .finished:
                handler(nil)
            }
            
            (result, cancellable) = (nil, nil)
        }, receiveValue: {
            guard case .none = result else {
                cancellable?.cancel()
                (result, cancellable) = (nil, nil)
                return
            }
            result = $0
        })
        
        return cancellable
    }
}
