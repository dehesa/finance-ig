@testable import IG
import XCTest
import Combine
import Foundation

final class PlaygroundTests: XCTestCase {
    func testPlay() {
        print(IG.API.Node.Market.printableDomain)
    }
}
