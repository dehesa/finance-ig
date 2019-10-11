import XCTest
import Combine
import Foundation

extension Publisher {
    /// Expects the receiving publisher to complete (with or without values) within the timeout on the `XCTestCase` given in the `wait` closure.
    ///
    /// The `wait` closure is given so it will trigger Xcode to print *red* the appropriate line.
    /// - parameter description: The expectation description. Try to express what it is expected.
    /// - parameter file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
    /// - parameter line: The line number on which failure occurred. Defaults to the line number on which this function was called.
    /// - parameter wait: Closure to call `wait` on a `XCTestCase`. It usually looks like: `{ self.wait(for: [$0], timeout: 2) }`
    /// - parameter expectation: The expectation created to be fulfilled in the `wait` closure.
    func expectsCompletion(_ description: String = "The publisher shall complete", file: StaticString = #file, line: UInt = #line, wait: (_ expectation: XCTestExpectation)->Void) {
        let e = XCTestExpectation(description: description)
        
        var cancellable: AnyCancellable?
        cancellable = self.sink(receiveCompletion: {
            cancellable = nil
            switch $0 {
            case .finished: e.fulfill()
            case .failure(let e): XCTFail("The publisher completed with failure when successfull completion was expected.\n\(e)\n", file: file, line: line)
            }
        }, receiveValue: { (_) in return })
        
        wait(e)
        cancellable?.cancel()
    }
    
    /// Expects the receiving publisher to complete with a failure within the timeout on the `XCTestCase` given in the `wait` closure.
    ///
    /// The `wait` closure is given so it will trigger Xcode to print *red* the appropriate line.
    /// - parameter description: The expectation description. Try to express what it is expected.
    /// - parameter file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
    /// - parameter line: The line number on which failure occurred. Defaults to the line number on which this function was called.
    /// - parameter wait: Closure to call `wait` on a `XCTestCase`. It usually looks like: `{ self.wait(for: [$0], timeout: 2) }`
    /// - parameter expectation: The expectation created to be fulfilled in the `wait` closure.
    func expectsFailure(_ description: String = "The publisher shall fail", file: StaticString = #file, line: UInt = #line, wait: (_ expectation: XCTestExpectation)->Void) {
        let e = XCTestExpectation(description: description)
        
        var cancellable: AnyCancellable?
        cancellable = self.sink(receiveCompletion: {
            cancellable = nil
            switch $0 {
            case .finished: XCTFail("The publisher completed successfully when a failure was expected", file: file, line: line)
            case .failure(_): e.fulfill()
            }
        }, receiveValue: { (_) in return })
        
        wait(e)
        cancellable?.cancel()
    }
    
    /// Expects the receiving publisher to produce a single value and then complete within the timeout on the `XCTestCase` given in the `wait` closure.
    ///
    /// The `wait` closure is given so it will trigger Xcode to print *red* the appropriate line.
    /// - parameter description: The expectation description. Try to express what it is expected.
    /// - parameter file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
    /// - parameter line: The line number on which failure occurred. Defaults to the line number on which this function was called.
    /// - parameter wait: Closure to call `wait` on a `XCTestCase`. It usually looks like: `{ self.wait(for: [$0], timeout: 2) }`
    /// - parameter expectation: The expectation created to be fulfilled in the `wait` closure.
    /// - returns: The value forwarded by the publisher.
    @discardableResult func expectsOne(_ description: String = "The publisher shall send a single value and complete", file: StaticString = #file, line: UInt = #line, wait: (_ expectation: XCTestExpectation)->Void) -> Self.Output {
        let e = XCTestExpectation(description: description)
        
        var cancellable: AnyCancellable?
        var result: Self.Output? = nil
        
        cancellable = self.sink(receiveCompletion: {
            cancellable = nil
            switch $0 {
            case .failure(let e):
                return XCTFail("The publisher completed with failure when successfull completion was expected\n\(e)\n", file: file, line: line)
            case .finished:
                guard case .some = result else {
                    return XCTFail("The publisher completed without outputting any value", file: file, line: line)
                }
                e.fulfill()
            }
        }, receiveValue: {
            guard case .none = result else {
                cancellable?.cancel()
                cancellable = nil
                return XCTFail("The publisher produced more than one value when only one was expected", file: file, line: line)
            }
            result = $0
        })
        
        wait(e)
        cancellable?.cancel()
        return result!
    }
    
    /// Expects the receiving publisher to produce zero, one, or many values and then complete within the timeout on the `XCTestCase` given in the `wait` closure.
    ///
    /// The `wait` closure is given so it will trigger Xcode to print *red* the appropriate line.
    /// - parameter description: The expectation description. Try to express what it is expected.
    /// - parameter file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
    /// - parameter line: The line number on which failure occurred. Defaults to the line number on which this function was called.
    /// - parameter wait: Closure to call `wait` on a `XCTestCase`. It usually looks like: `{ self.wait(for: [$0], timeout: 2) }`
    /// - parameter expectation: The expectation created to be fulfilled in the `wait` closure.
    /// - returns: The forwarded values by the publisher (it can be empty).
    @discardableResult func expectsAll(_ description: String = "The publisher produces zero or more values and complete", file: StaticString = #file, line: UInt = #line, wait: (_ expectation: XCTestExpectation)->Void) -> [Self.Output] {
        let e = XCTestExpectation(description: description)
        
        var cancellable: AnyCancellable?
        var result: [Self.Output] = []
        
        cancellable = self.sink(receiveCompletion: {
            cancellable = nil
            switch $0 {
            case .finished:
                e.fulfill()
            case .failure(let e):
                XCTFail("The publisher completed with failure when successfull completion was expected\n\(e)\n", file: file, line: line)
                fatalError()
            }
        }, receiveValue: { result.append($0) })
        
        wait(e)
        cancellable?.cancel()
        return result
    }
    
    /// Expects the receiving publisher to produce at least a given number of values.
    ///
    /// Once the publisher has produced the given amount of values, it will get cancel by this function.
    /// - precondition: `values` must be greater than zero.
    /// - parameter values: The number of values that will be checked and that the expectation is waiting for.
    /// - parameter description: The expectation description. Try to express what it is expected.
    /// - parameter file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
    /// - parameter line: The line number on which failure occurred. Defaults to the line number on which this function was called.
    /// - parameter check: The closure to be executed per value received.
    /// - parameter wait: Closure to call `wait` on a `XCTestCase`. It usually looks like: `{ self.wait(for: [$0], timeout: 2) }`
    /// - returns: An array of all the values forwarded by the publisher. 
    @discardableResult func expectsAtLeast(_ values: Int, _ description: String = "The publisher shall produce a givan amount of values", file: StaticString = #file, line: UInt = #line, each check: ((Output)->Void)? = nil, wait: (_ expectation: XCTestExpectation)->Void) -> [Self.Output] {
        precondition(values > 0)
        
        let e = XCTestExpectation(description: "Waiting for \(values) values")
        
        var result: [Self.Output] = []
        var cancellable: AnyCancellable?
        cancellable = self.sink(receiveCompletion: {
            cancellable = nil
            switch $0 {
            case .finished: if result.count == values { return e.fulfill() }
            case .failure(let e): XCTFail(String(describing: e), file: file, line: line)
            }
        }, receiveValue: { (output) in
            result.append(output)
            check?(output)
            guard result.count == values else { return }
            cancellable?.cancel()
            cancellable = nil
            e.fulfill()
        })
        
        wait(e)
        cancellable?.cancel()
        return result
    }
}

extension XCTestCase {
    /// Locks the current queue for `interval` seconds.
    /// - parameter timeout: The maximum number of seconds waiting (must be greater than zero).
    /// - parameter test: The `XCTestCase` where this expectation waiting is performed.
    func wait(for interval: TimeInterval) {
        precondition(interval > 0)
        
        let e = self.expectation(description: "Waiting for \(interval) seconds")
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) {
            $0.invalidate()
            e.fulfill()
        }
        
        self.wait(for: [e], timeout: interval)
        timer.invalidate()
    }
}
