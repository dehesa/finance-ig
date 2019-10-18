import IG
import XCTest
import Combine
import Foundation

final class PlaygroundTests: XCTestCase {
    func testPlay() {
//        print()
//        
//        let expectationA = self.expectation(description: "Wait A")
//        var cancellables = Set<AnyCancellable>()
//        
//        let api = API(rootURL: URL(string: "https://demo-api.ig.com/gateway/deal")!, credentials: nil, targetQueue: nil)
//        let user = API.User("<#fill_me#>", "<#fill_me#>")
//        
//        api.session.login(type: .oauth, key: "<#fill_me#>", user: user)
//            .flatMap { (_)  in api.session.get() }
//            .sink(receiveCompletion: { (completion) in
//                guard case .finished = completion else { print("Error A!!!"); fatalError() }
//                expectationA.fulfill()
//            }) { (session) in
//                print(session)
//        }.store(in: &cancellables)
//        
//        self.wait(for: [expectationA], timeout: 2)
//        
//        // ----------------
//        
//        let expectationB = self.expectation(description: "Wait B")
//        
//        api.applications.getAll()
//            .sink(receiveCompletion: { (completion) in
//                guard case .finished = completion else { print("Error B!!!"); fatalError() }
//                expectationB.fulfill()
//            }, receiveValue: {
//                for app in $0 {
//                    print(app)
//                }
//            }).store(in: &cancellables)
//        
//        self.wait(for: [expectationB], timeout: 2)
//        
//        print()
    }
}
