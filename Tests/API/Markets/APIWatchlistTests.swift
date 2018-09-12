import XCTest
import ReactiveSwift
@testable import IG

final class APIWatchlistTests: APITestCase {
    /// Tests the various watchlist retrieval endpoints.
    func testWatchlistRetrieval() {
        let endpoint = self.api.watchlists().on(value: {
            XCTAssertFalse($0.isEmpty)
        }).call(on: self.api) { (api, watchlists) in
            api.watchlist(id: watchlists.last!.identifier)
        }.on(value: {
            XCTAssertFalse($0.isEmpty)
        })
        
        self.test("Watchlist retrieval", endpoint, signingProcess: .oauth, timeout: 2)
    }
    
//    /// Tests to perform only on the server side.
//    func testWatchlistLifecycle() {
//        /// This will be filled up by the created watchlist.
//        var watchlistId: String? = nil
//        /// Epics to be added to the watchlist.
//        let startEpics = ["CS.D.EURUSD.MINI.IP", "CS.D.EURCHF.CFD.IP"].sorted()
//        let addedEpic = "CS.D.GBPEUR.CFD.IP"
//        let endEpics = (startEpics + [addedEpic]).sorted()
//
//        // 1. Creates a watchlist.
//        let endpoints = self.api.createWatchlist(name: "Test Watchlist", epics: startEpics).on(value: {
//            XCTAssertFalse($0.identifier.isEmpty)
//            XCTAssertTrue($0.areAllInstrumentAdded)
//            watchlistId = $0.identifier
//        }).call(on: self.api) { (api, result) in
//            // 2. Check the data of the created watchlist.
//            api.watchlist(id: result.identifier)
//        }.on(value: { (markets) in
//            let receivedEpics = markets.map { $0.instrument.epic }.sorted()
//            XCTAssertEqual(receivedEpics, startEpics)
//        }).call(on: self.api) { (api, markets) in
//            // 3. Add a new epic to the watchlist.
//            api.updateWatchlist(id: watchlistId!, addingEpic: addedEpic)
//        }.call(on: self.api) { (api, _) in
//            // 4. Retrieve data from the watchlist.
//            api.watchlist(id: watchlistId!)
//        }.on(value: { (markets) in
//            let receivedEpics = markets.map { $0.instrument.epic }.sorted()
//            XCTAssertEqual(receivedEpics, endEpics)
//        }).call(on: self.api) { (api, _) in
//            // 5. Removes the epic just added.
//            api.updateWatchlist(id: watchlistId!, removingEpic: addedEpic)
//        }.call(on: self.api) { (api, _) in
//            // 6. Retrieve data from the watchlist.
//            api.watchlist(id: watchlistId!)
//        }.on(value: { (markets) in
//            let receivedEpics = markets.map { $0.instrument.epic }.sorted()
//            XCTAssertEqual(receivedEpics, startEpics)
//        }).call(on: self.api) { (api, _) in
//            // 7. Deletes the whole test wachtlist.
//            api.deleteWatchlist(id: watchlistId!)
//        }
//
//        self.test("Watchlist lifecycle", endpoints, signingProcess: .oauth, timeout: 8)
//    }
}
