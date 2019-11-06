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
        
        func reset() {
            dispatchPrecondition(condition: .notOnQueue(self.queue))
            self.queue.sync { () -> Set<AnyCancellable> in
                let result = self.cancellables
                self.cancellables.removeAll()
                self.epics.removeAll()
                return result
            }.forEach { $0.cancel() }
        }
        
        /// Start monitoring the given epics and storing their price data in the database.
        /// - parameter epics: The markets to subscribe to.
        func monitor(epics: Set<IG.Market.Epic>) {
            dispatchPrecondition(condition: .notOnQueue(self.queue))
            guard !epics.isEmpty else { return }
            
            let prefix = "\t"
            var cancellable: AnyCancellable? = nil
            var filteredEpics: Set<Market.Epic> = .init()
            
            let cleanUp: ()->Void = { [weak self, weak cancellable] in
                guard let self = self else { return }
                self.queue.async {
                    self.epics.subtract(filteredEpics)
                    filteredEpics.removeAll()
                    
                    guard let subscriber = cancellable else { return }
                    self.cancellables.remove(subscriber)
                    cancellable = nil
                }
            }
            
            let subscriber = Subscribers.Sink<DB.PriceStreamed,Services.Error>(receiveCompletion: { [weak self] in
                let count = filteredEpics.count
                cleanUp()
                
                switch $0 {
                case .finished:
                    Console.print("\(prefix)The subscription to \(count) markets finished successfully\n")
                    let remaining = self?.epics.count ?? 0
                    if remaining > 0 { Console.print("\(prefix)There are still \(remaining) markets being monitored\n") }
                case .failure(let e):
                    let separator = String.init(repeating: "-", count: 30)
                    Console.print("\(prefix)The subscription to \(count) markets finished with an error\n\(separator)\n\(e.debugDescription)\(separator)\n")
                }
            }, receiveValue: { (data) in
                Console.print("\(prefix)Data received from epic: \(data.epic)\n")
            })
            cancellable = AnyCancellable(subscriber)
            self.cancellables.insert(cancellable!)
            
            // 1. Take out the markets that are already being monitored.
            DeferredResult<Set<IG.Market.Epic>,IG.Services.Error> { [unowned self] in
                filteredEpics = self.queue.sync { () -> Set<IG.Market.Epic> in
                    let result = epics.subtracting(self.epics)
                    self.epics.formUnion(result)
                    return result
                }
                Console.print("\(prefix)\(filteredEpics.count) markets will be monitored\n")
                return .success(filteredEpics)
            } // 2. Retrieve from the server the market info from those markets the database doesn't know about.
            .flatMap { [services = self.services] (epics) in
                services.database.markets.contains(epics: epics).map { (queryResult) in
                    // A. Select the epics whose markets are not in the database.
                    Set<IG.Market.Epic>(queryResult.compactMap { (!$0.isInDatabase) ? $0.epic : nil })
                }.mapError(IG.Services.Error.init)
                .flatMap { (unknownEpics) -> AnyPublisher<Never,Services.Error> in
                    if !unknownEpics.isEmpty {
                        Console.print("\(prefix)Retrieving API basic info for \(unknownEpics.count) of those markets...\n")
                    }
                    // B. Fetch the market information from the server for the selected epics.
                    return services.api.markets.getContinuously(epics: unknownEpics).mapError(IG.Services.Error.init)
                        .collect().map { $0.flatMap { $0 } }
                    // C. Store the retrieved information in the database
                        .flatMap { services.database.markets.update($0).mapError(IG.Services.Error.init) }
                        .eraseToAnyPublisher()
                    // D. Finish with the `filteredEpics` if everything when alright.
                }.then { () -> Result<Set<Market.Epic>,Services.Error>.Publisher in
                    Console.print("\(prefix)Connecting to IG through the Lightstreamer protocol...\n")
                    return Just(epics).setFailureType(to: IG.Services.Error.self)
                }
            } // 3. Connect the streamer and create all subscription publishers
            .flatMap { [services = self.services] (epics) in
                services.streamer.session.connect().mapError(IG.Services.Error.init).then {
                    epics.publisher.setFailureType(to: IG.Services.Error.self)
                }.map { (epic) in
                    (epic, services.streamer.price.subscribe(epic: epic, interval: .minute, fields: [.date, .isFinished, .numTicks, .openBid, .openAsk, .closeBid, .closeAsk, .lowestBid, .lowestAsk, .highestBid, .highestAsk], snapshot: false))
                }
            } // 4. Execute all subscriptions (a publisher per event).
            .flatMap { [services = self.services, weak self] (epic, publisher) in
                    // A. Execute the publisher and if it fails try again.
                publisher.retry(2).mapError(IG.Services.Error.init)
                    // B. Filter the candles that are not "completed".
                    .filter { $0.candle.isFinished ?? false }
                    // C. Update those prices in the database.
                    .updatePrice(database: services.database)
                    // D. Catch any error so all other subscription may continue.
                    .catch { (error) -> Empty<IG.DB.PriceStreamed,IG.Services.Error> in
                        self?.queue.async {
                            filteredEpics.remove(epic)
                            self?.epics.remove(epic)
                        }
                        Console.print(error: "\(prefix)The subscription to \"\(epic)\" failed and was closed!")
                        return .init(completeImmediately: true)
                    }
            } // 5. Handle the eventually of a cancel (cleaning the program of the epics trying to be subscribed).
            .handleEvents(receiveCancel: { [weak self] in
                let count = filteredEpics.count
                cleanUp()
                Console.print("\(prefix)The subscription to \(count) markets got cancelled!\n")
                let remaining = self?.epics.count ?? 0
                if remaining > 0 { Console.print("\(prefix)There are still \(remaining) markets being monitored\n") }
            }).subscribe(subscriber)
        }
    }
}
