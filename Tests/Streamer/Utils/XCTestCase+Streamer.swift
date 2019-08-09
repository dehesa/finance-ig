import XCTest
import ReactiveSwift
@testable import IG

extension XCTestCase {
    /// Convenience function to test streamer `SignalProducer`s.
    ///
    /// It executes the `expression` passing the `value` closure to all values and wait for the signal to complete. Optionally it takes a number of values before forcing complete.
    /// The whole setup is under a given timeout. If the setup doesn't complete in the given time, an error is thrown and handle.
    /// Finally, all values are passed to the complete closure, in case a whole behavior test must be checked.
    /// - parameter expression: The signal producer to test.
    /// - parameter value: Optional check on all values.
    /// - parameter take: The optional amount of values to take before forcing *complete*.
    /// - parameter timeout: The time to wait for or an error is sent.
    /// - parameter scheduler: The scheduler where the time will be waited for.
    /// - parameter complete: Optional closure to check all received values.
    func test<V>(_ expression: @autoclosure ()->SignalProducer<V,Streamer.Error>, value: ((V)->Void)? = nil, take: Int? = nil, timeout: TimeInterval, on scheduler: DateScheduler, complete: (([V])->Void)? = nil) {
        var collection: [V] = []
        var producer = expression().on(value: { collection.append($0); value?($0) })
        
        let suggestion = "Check that you are running the tests while the markets are open (on weekends, the subscription doesn't usually work)."
        
        if let take = take {
            let message = "The \(timeout) seconds interval timeout elapsed. Only \(collection.count) values out of the \(take) requested were gathered. Values:\n\(collection)"
            producer = producer
                .take(first: take)
                .timeout(after: timeout, raising: .invalidRequest(message, suggestion: suggestion), on: scheduler)
        } else {
            let message = "The \(timeout) interval tiemout elapsed and the producer hasn't completed. Values:\n\(collection)"
            producer = producer
                .timeout(after: timeout, raising: .invalidRequest(message, suggestion: suggestion), on: scheduler)
        }
        
        XCTAssertNoThrow(try producer.wait().get())
        
        if let complete = complete {
            complete(collection)
        }
    }
}
