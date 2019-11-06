import IG
import Conbini
import Combine
import Foundation

extension App {
    /// A subprogram monitoring the real-time price protocol.
    final class Subscription: Program {
        /// The priviledge queue doing synchronization operations.
        private let queue: DispatchQueue
        /// The main app queue.
        unowned let mainQueue: DispatchQueue
        
        /// The supported IG services.
        unowned let services: IG.Services
        /// The epics being currently monitored/subscribed.
        private(set) var epics: Set<IG.Market.Epic>
        /// Instances to cancel any ongoing asynchronous operation.
        private var cancellables: Set<AnyCancellable>
        
        /// Designated initializer giving the queue where result will be output and the services used to connect to the IG platform.
        init(queue: DispatchQueue, services: IG.Services) {
            self.queue = DispatchQueue(label: queue.label + ".subscription")
            self.mainQueue = queue
            self.services = services
            self.epics = .init()
            self.cancellables = .init()
        }
        
        deinit {
            self.cancellables.forEach { $0.cancel() }
        }
        
        /// Start monitoring the given epics and storing their price data in the database.
        /// - parameter epics: The markets to subscribe to.
        func monitor(epics: Set<IG.Market.Epic>) {
            guard !epics.isEmpty else { return }

            let prefix = "\t"
            var targetedEpics = Set<Market.Epic>()
            
//            let subscriber = Subscribers.Sink<DB.Price,IG.Services.Error>(receiveCompletion: { (completion) in
//                <#code#>
//            }, receiveValue: { (<#DB.Price#>) in
//                <#code#>
//            })
            
            let publisher = DeferredResult<Set<IG.Market.Epic>,IG.Services.Error> {
                    // 1. Filter all epics that are currently being managed by this program.
                    targetedEpics = self.queue.sync { () -> Set<IG.Market.Epic> in
                        let result = epics.subtracting(self.epics)
                        self.epics.formUnion(result)
                        return result
                    }
                    return .success(targetedEpics)
                }.flatMap { [services = self.services] (epics) in
                    // 2. Identify the epics whose markets are not in the database.
                    services.database.markets.contains(epics: epics)
                        .map { (result) -> Set<IG.Market.Epic> in
                            .init(result.filter { (epic, isInDatabase) -> Bool in
                                if !isInDatabase { Console.print("\(prefix)A subscription to \"\(epic)\" won't be established, since the market is not initialized in the database.") }
                                return isInDatabase
                            }.map { $0.epic })
                        }.mapError(IG.Services.Error.init)
                        // 3. Fetch the market information from the server for the epics that are not tracked in the database.
                        .flatMap { (epics) in
                            services.api.markets.getContinuously(epics: epics)
                                .mapError(IG.Services.Error.init)
                                .collect().map { $0.flatMap { $0 } }
                                .flatMap { (markets) in
                                    services.database.markets.update(markets).mapError(IG.Services.Error.init)
                                }
                        }.then { Just(epics).setFailureType(to: IG.Services.Error.self) }
                }.flatMap { [services = self.services] (epics) in
                    // 4. Connect to the streamer
                    services.streamer.session.connect()
                        .mapError(IG.Services.Error.init)
                        .then { epics.publisher.setFailureType(to: IG.Services.Error.self) }
                        // 5. Subscribe to all targeted epics.
                        .map { (epic) in
                            (epic, services.streamer.charts.subscribe(to: epic, interval: .minute, fields: [.date, .isFinished, .numTicks, .openBid, .openAsk, .closeBid, .closeAsk, .lowestBid, .lowestAsk, .highestBid, .highestAsk], snapshot: false))
                        }
                // 6. Handle the eventually of a completion failure or a cancel (cleaning the program of the epics trying to be subscribed).
                }.handleEvents(receiveCompletion: { [weak self] (completion) in
                    guard case .failure = completion else { return }
                    Swift.print("## Failure received (setup) ##")
                    self?.queue.sync { self!.epics.subtract(targetedEpics) }
                }, receiveCancel: { [weak self] in
                    Swift.print("## Cancel received (setup) ##")
                    self?.queue.sync { self!.epics.subtract(targetedEpics) }
                }) // 7. Execute all subscriptions.
                .flatMap { [services = self.services, weak self] (epic, publisher) in
                    publisher
                        .retry(2)
                        // 8. Filter the candles that are not done for the minute interval.
                        .filter { $0.candle.isFinished ?? false }
                        // 9. Update those prices in the database.
                        .updatePrices(database: services.database)
                        .catch { _ in Empty<IG.DB.Price,IG.Services.Error>(completeImmediately: true) }
                        .handleEvents(receiveCompletion: { [weak self] _ in
                            Console.print(error: "\(prefix)The subscription to \"\(epic)\" failed and was closed.")
                            self?.queue.async { self!.epics.remove(epic) }
                        }, receiveCancel: {
                            Swift.print("## Cancel received (single subscriber) ##")
                            self?.queue.async { self!.epics.remove(epic) }
                        })
                }
                
//                .subscribe(subscriber)
            
            self.run(publisher: publisher, identifier: "subscription.epics.\(epics.count)")
        }
        
        func reset() {
            dispatchPrecondition(condition: .notOnQueue(self.queue))
            
            let cancellables = self.queue.sync { () -> Set<AnyCancellable> in
                let result = self.cancellables
                self.cancellables.removeAll()
                self.epics.removeAll()
                return result
            }
            
            cancellables.forEach { $0.cancel() }
        }
    }
}

extension App.Subscription {
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
        }, receiveValue: { _ in })
        
        let cancellable = AnyCancellable(subscriber)
        self.cancellables.insert(cancellable)
        
        cleanUp = { [weak self, weak cancellable] in
            guard let self = self, let target = cancellable else { return }
            self.queue.sync { _ = self.cancellables.remove(target) }
        }
        publisher.subscribe(subscriber)
    }
}
