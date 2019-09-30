import Combine
import Foundation

extension Publisher {
    /// Locks the current queue waiting for the receiving publisher to finish.
    /// - precondition: The publisher must finish successfully and it must not input any value. In any other case a `fatalError` is produced.
    /// - parameter timeout: The maximum time the semaphore will be waiting.
    func wait(timeout: DispatchTimeInterval = .seconds(2), file: StaticString = #file, line: UInt = #line) {
        let semaphore = DispatchSemaphore(value: 0)
        
        var cancellable: AnyCancellable?
        cancellable = self.sink(receiveCompletion: {
            cancellable = nil
            switch $0 {
            case .finished: semaphore.signal()
            case .failure(let e): fatalError("The publisher forwarded an error\n\(e)\n", file: file, line: line)
            }
        }, receiveValue: { (_) in return })
        
        guard case .success = semaphore.wait(timeout: .now() + timeout) else {
            fatalError("The publisher didn't complete before the timeout ellapsed.", file: file, line: line)
        }
        cancellable?.cancel()
    }
    
    /// Locks the current queue waiting for the receiving publisher to finish.
    /// - precondition: The publisher must finish successfully and it must input ONE value. In any other case a `fatalError` is produced.
    /// - parameter timeout: The maximum time the semaphore will be waiting.
    /// - returns: The value forwarded by the publisher.
    func waitForOne(timeout: DispatchTimeInterval = .seconds(2), file: StaticString = #file, line: UInt = #line) -> Self.Output {
        let semaphore = DispatchSemaphore(value: 0)
        
        var result: Self.Output? = nil
        var cancellable: AnyCancellable?
        cancellable = self.sink(receiveCompletion: {
            cancellable = nil
            switch $0 {
            case .finished: semaphore.signal()
            case .failure(let e): fatalError("The publisher forwarded an error:\n\n\(e)\n", file: file, line: line)
            }
        }, receiveValue: {
            guard case .none = result else {
                fatalError("The publisher returned more than one value", file: file, line: line)
            }
            result = $0
        })
        
        guard case .success = semaphore.wait(timeout: .now() + timeout) else {
            fatalError("The publisher didn't complete before the timeout ellapsed.", file: file, line: line)
        }
        cancellable?.cancel()
        return result!
    }
    
    /// Locks the current queue waiting for the receiving publisher to finish.
    /// - precondition: The publisher must finish successfully and it must not input any value. In any other case a `fatalError` is produced.
    /// - parameter timeout: The maximum time the semaphore will be waiting.
    /// - returns: An array of all the values forwarded by the publisher.
    func waitForAll(timeout: DispatchTimeInterval = .seconds(2), file: StaticString = #file, line: UInt = #line) -> [Self.Output] {
        let semaphore = DispatchSemaphore(value: 0)
        
        var result: [Self.Output] = []
        var cancellable: AnyCancellable?
        cancellable = self.sink(receiveCompletion: {
            cancellable = nil
            switch $0 {
            case .finished: semaphore.signal()
            case .failure(let e): fatalError("The publisher forwarded an error:\n\n\(e)\n", file: file, line: line)
            }
        }, receiveValue: { result.append($0) })
        
        guard case .success = semaphore.wait(timeout: .now() + timeout) else {
            fatalError("The publisher didn't complete before the timeout ellapsed.", file: file, line: line)
        }
        cancellable?.cancel()
        return result
    }
}
