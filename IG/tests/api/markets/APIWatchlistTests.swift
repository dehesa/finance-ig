import IG
import ConbiniForTesting
import XCTest

final class APIWatchlistTests: XCTestCase {
    /// The test account being used for the tests in this class.
    private let _acc = Test.account(environmentKey: Test.defaultEnvironmentKey)
    
    /// Tests the various watchlist retrieval endpoints.
    func testWatchlistRetrieval() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: self.apiCredentials(from: self._acc), targetQueue: nil)
        
        let watchlists = api.watchlists.getAll().expectsOne(timeout: 2, on: self)
        XCTAssertFalse(watchlists.isEmpty)
        for watchlist in watchlists {
            XCTAssertFalse(watchlist.id.isEmpty)
            XCTAssertFalse(watchlist.name.isEmpty)
        }
        
        let target = watchlists.last!
        let markets = api.watchlists.getMarkets(from: target.id).expectsOne(timeout: 2, on: self)
        XCTAssertFalse(markets.isEmpty)
    }

    /// Tests to perform only on the server side.
    func testWatchlistLifecycle() {
        let api = Test.makeAPI(rootURL: self._acc.api.rootURL, credentials: self.apiCredentials(from: self._acc), targetQueue: nil)
        /// Epics to be added to the watchlist.
        let startEpics: [IG.Market.Epic] = ["CS.D.EURUSD.MINI.IP", "CS.D.EURCHF.CFD.IP"].sorted { $0 > $1 }
        let addedEpic: IG.Market.Epic = "CS.D.GBPEUR.CFD.IP"
        let endEpics = (startEpics + [addedEpic]).sorted { $0 > $1 }

        // 1. Creates a watchlist.
        let w = api.watchlists.create(name: "Test Watchlist", epics: startEpics).expectsOne(timeout: 2, on: self)
        XCTAssertFalse(w.identifier.isEmpty)
        XCTAssertTrue(w.areAllInstrumentsAdded)
        // 2. Check the data of the created watchlist.
        let startingMarkets = api.watchlists.getMarkets(from: w.identifier).expectsOne(timeout: 2, on: self)
        XCTAssertEqual(startEpics, startingMarkets.map { $0.instrument.epic }.sorted { $0 > $1 })
        // 3. Add a new epic to the watchlist.
        api.watchlists.update(identifier: w.identifier, addingEpic: addedEpic).expectsCompletion(timeout: 1.5, on: self)
        // 4. Retrieve data from the watchlist.
        let midMarkets = api.watchlists.getMarkets(from: w.identifier).expectsOne(timeout: 2, on: self)
        XCTAssertEqual(endEpics, midMarkets.map { $0.instrument.epic }.sorted { $0 > $1 })
        // 5. Removes the epic just added.
        api.watchlists.update(identifier: w.identifier, removingEpic: addedEpic).expectsCompletion(timeout: 1.5, on: self)
        // 6. Retrieve data from the watchlist.
        let endMarkets = api.watchlists.getMarkets(from: w.identifier).expectsOne(timeout: 2, on: self)
        XCTAssertEqual(startEpics, endMarkets.map { $0.instrument.epic }.sorted { $0 > $1 })
        // 7. Deletes the whole test wachtlist.
        api.watchlists.delete(identifier: w.identifier).expectsCompletion(timeout: 1.5, on: self)
    }
}
