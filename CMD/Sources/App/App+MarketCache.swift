import IG
import Conbini
import Combine
import Foundation

extension App {
    ///
    final class MarketCache: Program {
        /// The main app queue.
        private unowned let mainQueue: DispatchQueue
        /// All IG services.
        private unowned let services: IG.Services
        /// The epics being currently monitored/subscribed.
        private(set) var epics: Set<IG.Market.Epic>
        /// Instances to cancel any ongoing asynchronous operation.
        private var cancellables: Set<AnyCancellable>
        
        /// Designated initializer giving the queue where result will be output and the services used to connect to the IG platform.
        init(queue: DispatchQueue, services: IG.Services) {
            self.mainQueue = queue
            self.services = services
            self.epics = .init()
            self.cancellables = .init()
        }
        
        deinit {
            self.cancellables.forEach { $0.cancel() }
        }
        
        /// Start monitoring the given epics and caching their price data in the database.
        func monitor(epics: [IG.Market.Epic]) {
            let targetEpics = Set(epics).subtracting(self.epics)
            guard !targetEpics.isEmpty else { return }
            
            let publisher = Self.fetchPublisher(epics: targetEpics, api: services.api, database: services.database)
                .then { [streamer = self.services.streamer] in
                    streamer.session.connect().mapError(IG.Services.Error.init)
                }.then {
                    self.subscribePublisher(epics: targetEpics, interval: .minute)
                        .setFailureType(to: IG.Services.Error.self)
                }.filter { $0.candle.isFinished ?? false }
                .updatePrices(database: self.services.database)
            self.run(publisher: publisher, identifier: "market.cache.epics.\(targetEpics.count)")
        }
    }
}

extension App.MarketCache {
    func shutdown() {
        
    }
}

extension App.MarketCache {
    /// Starts the given publishers and hold a strong reference to the subscription within the `cancellables` property.
    ///
    /// If the publisher finishes, the `cancellables` property is properly cleanup.
    /// - parameter publisher: Combine publisher that will be running during the lifecycle of this instance.
    /// - parameter identifier: The publisher identifier used for debugging purposes.
    private func run<P:Publisher>(publisher: P, identifier: String) {
        var cleanUp: (()->Void)? = nil
        let subscriber = Subscribers.Sink<P.Output,P.Failure>(receiveCompletion: {
            switch $0 {
            case .finished: Console.print("Publisher \"\(identifier)\" finished successfully.\n")
            case .failure(let error): Console.print(error: error, prefix: "Publisher \"\(identifier)\" encountered an error.\n")
            }
            cleanUp?()
        }, receiveValue: { _ in return })
        
        let cancellable = AnyCancellable(subscriber)
        self.cancellables.insert(cancellable)
        
        cleanUp = { [weak self, weak cancellable] in
            guard let self = self, let target = cancellable else { return }
            self.cancellables.remove(target)
        }
        publisher.subscribe(subscriber)
    }
    
    /// Returns a publisher used to filter the epics that are not in the database and retrieve them from the server.
    /// - parameter epics: The markets that will be monitored.
    private static func fetchPublisher(epics: Set<IG.Market.Epic>, api: IG.API, database: IG.DB) -> IG.Services.DiscretePublisher<Never> {
        return database.markets.contains(epics: .init(epics))
            .map { $0.filter { !$0.isInDatabase }.map { $0.epic } }
            .mapError(IG.Services.Error.init)
            .flatMap { (epics) -> AnyPublisher<[IG.API.Market],IG.Services.Error> in
                if epics.isEmpty {
                    return Just([])
                        .setFailureType(to: IG.Services.Error.self)
                        .eraseToAnyPublisher()
                } else if epics.count <= 50 {
                    return api.markets.get(epics: .init(epics))
                        .mapError(IG.Services.Error.init)
                        .eraseToAnyPublisher()
                } else {
                    return api.markets.getContinuously(epics: .init(epics))
                    .collect()
                    .mapError(IG.Services.Error.init)
                    .map { $0.flatMap { $0 } }
                    .eraseToAnyPublisher()
                }
            }.flatMap {
                database.markets.update($0)
                    .mapError(IG.Services.Error.init)
            }.eraseToAnyPublisher()
    }
    
    /// Returns a publisher that subscribe to all markets (given as epics) for the given interval.
    /// - parameter epics: The markets that will be monitored.
    /// - parameter interval: The time interval to aggregate data as.
    private func subscribePublisher(epics: Set<IG.Market.Epic>, interval: IG.Streamer.Chart.Aggregated.Interval) -> AnyPublisher<IG.Streamer.Chart.Aggregated,Never> {
//        guard !epics.isEmpty else { return Complete }
        
        let fields: Set<IG.Streamer.Chart.Aggregated.Field> = [.date, .isFinished, .numTicks, .openBid, .openAsk, .closeBid, .closeAsk, .lowestBid, .lowestAsk, .highestBid, .highestAsk]
        
        return epics.publisher.map { [weak self, streamer = self.services.streamer] (epic) in
                streamer.charts.subscribe(to: epic, interval: interval, fields: fields)
                    .retry(2)
                    .catch { (error) -> Empty<Streamer.Chart.Aggregated,Never> in
                        self?.epics.remove(epic)
                        return .init(completeImmediately: true)
                    }
            }.collect()
            .flatMap { (streamSubscriptions) in
                Publishers.MergeMany(streamSubscriptions)
            }.eraseToAnyPublisher()
    }
}
