import XCTest
import ReactiveSwift
@testable import IG

final class StreamerMarketTests: XCTestCase {
    func testMarketSubscriptions() {
        // let streamer = Test.makeStreamer(rootURL: URL(string: "file://Streamer")!, credentials: Test.credentials.streamer, autoconnect: false)
        let streamer = Test.makeStreamer(autoconnect: true)
        
        let expectation = self.expectation(description: "Subscription signal")
        let epic: Epic = "CS.D.EURGBP.MINI.IP"
        var disposable: Disposable? = nil
        var countDown: Int = 3
        
        disposable = streamer.markets.subscribe(to: epic, Set(Streamer.Market.Field.allCases)).start {
            switch $0 {
            case .value(let market):
                XCTAssertEqual(market.epic, epic)
                XCTAssertNotNil(market.status)
                XCTAssertNotNil(market.date)
                XCTAssertNotNil(market.isDelayed)
                XCTAssertNotNil(market.bid)
                XCTAssertNotNil(market.ask)
                
                print(market)
                
                countDown -= 1
                if (countDown <= 0) {
                    disposable?.dispose()
                    disposable = nil
                }
            case .completed:
                XCTFail("The signal should have interrupted since the disposable was used.")
            case .interrupted:
                expectation.fulfill()
            case .failed(let error):
                XCTFail(error.debugDescription)
            }
        }
        
        self.wait(for: [expectation], timeout: 8)

        streamer.session.unsubscribeAll()
        XCTAssertNoThrow(try SignalProducer.empty(after: 2, on: QueueScheduler(suffix: ".streamer.market.test")).wait().get())
    }
    
//    func testSprintMarkets() {
//        let streamer = Test.makeStreamer(autoconnect: true)
//
//        let expectation = self.expectation(description: "Subscription signal")
//        let epic: Epic = "CS.D.NZDEUR.CFD.IP"
//
//        streamer.markets.subscribeSprint(to: epic, [.status, .strikePrice, .odds]).start { (event) in
//            print(event)
//        }
//
//        self.wait(for: [expectation], timeout: 5)
//    }
}
