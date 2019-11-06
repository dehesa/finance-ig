import IG
import Conbini
import Combine
import Foundation

extension App {
    /// A subprogram querying the server for all available data that is not already in the database.
    final class BatchUpdate: Program {
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
            self.queue = DispatchQueue(label: queue.label + ".batchupdate")
            self.mainQueue = queue
            self.services = services
            self.epics = .init()
            self.cancellables = .init()
        }
        
        /// Ask the database for missing price datapoints and query those to the server.
        func update(epics: Set<IG.Market.Epic>, scrappedCredentials: (cst: String, security: String), handler: @escaping (Result<Void,Swift.Error>)->Void) {
            dispatchPrecondition(condition: .notOnQueue(self.queue))
            
            #warning("Add logic to remove this precondition")
//            let targetedEpics = self.queue.sync {
//                let result = epics.subtracting(self.epics)
//                self.epics.formUnion(result)
//                return result
//            }
            
            let publisher = epics.publisher.map { (epic) in
                self.services.api.scrapped.getLastAvailablePrices(epic: epic, resolution: .minute, scrappedCredentials: scrappedCredentials)
                    .mapError(IG.Services.Error.init)
                    .flatMap { [weak self] (prices) -> AnyPublisher<Never,IG.Services.Error> in
                        guard let self = self else {
                            return Fail(error: IG.Services.Error.user("Session expired", suggestion: "Keep a strong bond to services")).eraseToAnyPublisher()
                        }

                        return self.services.database.price.update(prices, epic: epic)
                            .mapError(IG.Services.Error.init)
                            .eraseToAnyPublisher()
                    }
                }.sequentialFlatMap()
            
            self.run(publisher: publisher, identifier: "batchupdate.prices") { [weak self] (completion) in
                if let self = self {
                    dispatchPrecondition(condition: .notOnQueue(self.queue))
                    
                    self.queue.sync {
                        self.epics.subtract(epics)
                    }
                }
                
                switch completion {
                case .finished: handler(.success(()))
                case .failure(let error): handler(.failure(error))
                }
            }
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

extension App.BatchUpdate {
    /// Starts the given publishers and hold a strong reference to the subscription within the `cancellables` property.
    ///
    /// If the publisher finishes, the `cancellables` property is properly cleanup.
    /// - parameter publisher: Combine publisher that will be running during the lifecycle of this instance.
    /// - parameter identifier: The publisher identifier used for debugging purposes.
    private func run<P:Publisher>(publisher: P, identifier: String, handler: @escaping (_ completion: Subscribers.Completion<P.Failure>)->Void) {
        var cleanUp: (()->Void)? = nil
        
        let subscriber = Subscribers.Sink<P.Output,P.Failure>(receiveCompletion: {
            switch $0 {
            case .finished: Console.print("Publisher \"\(identifier)\" finished successfully.\n")
            case .failure(let error): Console.print(error: error, prefix: "Publisher \"\(identifier)\" encountered an error.\n")
            }
            cleanUp?()
            handler($0)
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
