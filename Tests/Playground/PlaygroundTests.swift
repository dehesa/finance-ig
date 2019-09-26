//@testable import IG
import IG
import XCTest
import Combine

final class PlaygroundTests: XCTestCase {
    func testPlay() {
        print()
        let expectation = self.expectation(description: "Wait")
        var cancellables = Set<AnyCancellable>()
        
        let api = API(rootURL: URL(string: "https://demo-api.ig.com/gateway/deal")!, credentials: nil, targetQueue: nil)
        let user = API.User("<#name#>", "<#name#>")
        
        api.session.login(type: .oauth, key: "<#name#>", user: user)
            .flatMap { (_)  in api.session.get() }
            .sink(receiveCompletion: { (completion) in
                print("Completed")
                expectation.fulfill()
            }) { (session) in
                print(session)
        }.store(in: &cancellables)
        
        self.wait(for: [expectation], timeout: 5)
        print()
    }
}
