import XCTest
import Combine
@testable import IG

class CombineTests: XCTestCase {
    /// Test a normal "happy path" example for the custom "then" combine operator.
    func testThenPassthrough() {
        let e = self.expectation(description: "Successful completion")
        let queue = DispatchQueue.main
        
        let subject = PassthroughSubject<Int,IG.API.Error>()
        let cancellable = subject.then {
            ["A", "B", "C"].publisher.setFailureType(to: IG.API.Error.self)
        }.sink(receiveCompletion: { _ in e.fulfill() }) { _ in return }
        
        queue.asyncAfter(deadline: .now() + .milliseconds(100)) { subject.send(0) }
        queue.asyncAfter(deadline: .now() + .milliseconds(200)) { subject.send(1) }
        queue.asyncAfter(deadline: .now() + .milliseconds(300)) { subject.send(2) }
        queue.asyncAfter(deadline: .now() + .milliseconds(400)) { subject.send(completion: .finished) }
        
        self.wait(for: [e], timeout: 1)
        cancellable.cancel()
    }
    
    ///
    func testThenFailure() {
        let e = self.expectation(description: "Failure on origin")
        let queue = DispatchQueue.main
        
        let subject = PassthroughSubject<Int,IG.API.Error>()
        let cancellable = subject.then {
            Future<String,IG.API.Error> { (promise) in
                queue.asyncAfter(deadline: .now() + .milliseconds(200)) { promise(.success("Completed")) }
            }
        }.sink(receiveCompletion: { (completion) in
            guard case .failure(let error) = completion,
                case .sessionExpired = error.type else { return }
            e.fulfill()
        }) { _ in return }
        
        queue.asyncAfter(deadline: .now() + .milliseconds(50)) { subject.send(0) }
        queue.asyncAfter(deadline: .now() + .milliseconds(100)) { subject.send(completion: .failure(.sessionExpired())) }
        
        self.wait(for: [e], timeout: 2)
        cancellable.cancel()
    }
}
