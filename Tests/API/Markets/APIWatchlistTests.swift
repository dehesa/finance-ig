@testable import IG
import ReactiveSwift
import XCTest

final class APIWatchlistTests: XCTestCase {
    /// Tests the various watchlist retrieval endpoints.
    func testWatchlistRetrieval() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        
        let watchlists = try! api.watchlists.getAll().single()!.get()
        XCTAssertFalse(watchlists.isEmpty)
        
        let target = watchlists.last!
        let markets = try! api.watchlists.getMarkets(from: target.identifier).single()!.get()
        XCTAssertFalse(markets.isEmpty)
    }

    /// Tests to perform only on the server side.
    func testWatchlistLifecycle() {
        let api = Test.makeAPI(credentials: Test.credentials.api)
        /// Epics to be added to the watchlist.
        let startEpics: [IG.Epic] = ["CS.D.EURUSD.MINI.IP", "CS.D.EURCHF.CFD.IP"].sorted { $0.rawValue > $1.rawValue }
        let addedEpic: IG.Epic = "CS.D.GBPEUR.CFD.IP"
        let endEpics = (startEpics + [addedEpic]).sorted { $0.rawValue > $1.rawValue }

        // 1. Creates a watchlist.
        let watchlist = try! api.watchlists.create(name: "Test Watchlist", epics: startEpics).single()!.get()
        XCTAssertFalse(watchlist.identifier.isEmpty)
        XCTAssertTrue(watchlist.areAllInstrumentsAdded)
        // 2. Check the data of the created watchlist.
        let startingMarkets = try! api.watchlists.getMarkets(from: watchlist.identifier).single()!.get()
        XCTAssertEqual(startEpics, startingMarkets.map { $0.instrument.epic }.sorted { $0.rawValue > $1.rawValue })
        // 3. Add a new epic to the watchlist.
        try! api.watchlists.update(identifier: watchlist.identifier, addingEpic: addedEpic).single()!.get()
        // 4. Retrieve data from the watchlist.
        let midMarkets = try! api.watchlists.getMarkets(from: watchlist.identifier).single()!.get()
        XCTAssertEqual(endEpics, midMarkets.map { $0.instrument.epic }.sorted { $0.rawValue > $1.rawValue })
        // 5. Removes the epic just added.
        try! api.watchlists.update(identifier: watchlist.identifier, removingEpic: addedEpic).single()!.get()
        // 6. Retrieve data from the watchlist.
        let endMarkets = try! api.watchlists.getMarkets(from: watchlist.identifier).single()!.get()
        XCTAssertEqual(startEpics, endMarkets.map { $0.instrument.epic }.sorted { $0.rawValue > $1.rawValue })
        // 7. Deletes the whole test wachtlist.
        try! api.watchlists.delete(identifier: watchlist.identifier).single()!.get()
    }
}
