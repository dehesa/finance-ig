@testable import IG
import ReactiveSwift
import Foundation

extension StreamerFileSession {
    /// A session that uses files as data source.
    final class SubscriptionSession: StreamerSubscriptionSession {
        let mode: String
        let items: [Any]?
        let fields: [Any]?
        fileprivate(set) var isActive: Bool = false
        fileprivate(set) var isSubscribed: Bool = false
        /// Subscription operation variables.
        ///
        /// This variables are only set during active subscription.
        fileprivate var operation: (queue: DispatchQueue, signal: Signal<StreamerFileSession.SubscriptionSession.Event,Never>, disposable: Disposable?)? = nil
        /// Weak storage for subscription session delegates
        ///
        /// All objects in the array comply with `StreamerSubscriptionDelegate`.
        private var delegatesWeak: WeakArray<AnyObject> = []
        
        /// Creates a file subscription session that looks into the bundle file system for a file specifiying which messages to send.
        /// - parameter mode: The Lightstreamer mode to use for the subscription.
        /// - parameter items: The files to be used in the data sources.
        /// - parameter fields: The variables that are being targeted.
        init(mode: String, items: Set<String>, fields: Set<String>) {
            self.mode = mode
            self.items = items.map { $0 as Any }
            self.fields = fields.map { $0 as Any }
        }
        
        deinit {
            self.stop()
        }
        
        func add(delegate: StreamerSubscriptionDelegate) {
            self.delegatesWeak.clean()
            self.delegatesWeak.append(delegate)
        }
        
        func remove(delegate: StreamerSubscriptionDelegate) {
            self.delegatesWeak.clean()
            self.delegatesWeak.remove(element: delegate)
        }
    }
}

extension StreamerFileSession.SubscriptionSession {
    /// Subscribes to the items and fields stored in the receiving subscription and it starts sending the events stored in the indicated file.
    /// - parameter seconds: The amount of seconds between events (e.g. `[1, 2, 1, 0, 2]`). If the array is empty, 1 second is assumed. If the array `count` is smaller than the amount of events. The seconds array is wrapped around (starting again from the beginning).
    /// - parameter rootURL: The file url to append as root of the item name (e.g. `file://Streamer`).
    /// - returns: `true` if the subscription was successful; `false` otherwise or if the subscription was previously active.
    func start(every seconds: [UInt], rootURL: URL) -> Bool {
        // You cannot start if the subscription is already active.
        guard !self.isActive else { return false }
        self.isActive = true
        
        // For each subscribed item, compute its name, position, and file URL.
        let items = self.items!.map { (item) -> Result<(name: String, url: URL),Error> in
        // Find the file's name.
            guard let name = item as? String, !name.isEmpty else {
                return .failure(.invalidURL(item))
            }
            
            var url = rootURL
            if let range = name.range(of: ":", options: .literal) {
                let folder = String(name[name.startIndex..<range.lowerBound])
                if !folder.isEmpty { url.appendPathComponent(folder, isDirectory: true) }
                
                let file = String(name[range.upperBound..<name.endIndex])
                guard !file.isEmpty else { return .failure(.invalidURL(name)) }
                url.appendPathComponent(file, isDirectory: false)
            } else {
                url.appendPathComponent(name, isDirectory: false)
            }
            
            let jsonExtension = "json"
            if url.pathExtension != jsonExtension { url.appendPathExtension(jsonExtension) }
            return .success((name, url))
        // Load and unpack the files.
        }.map { (result) -> Result<(String,StreamerMockedJSON),Error> in
            result.flatMap {
                do {
                    let data = try Data(contentsOf: $0.url)
                    return .success(($0.name, try JSONDecoder().decode(StreamerMockedJSON.self, from: data)))
                } catch let error {
                    return .failure(.invalidFile(underlying: error))
                }
            }
        // Construct a time array for all the events. In case that less amount of seconds are provided, wrap it around.
        }.map { (result) -> Result<(String,Zip2Sequence<[StreamerMockedJSON.Event],[Int]>),Error> in
            // Check if the spacing seconds is given, if not, assume 1 second.
            let times = (!seconds.isEmpty) ? seconds : [1]
            
            return result.map { (name, file) in
                var total: Int = 0
                let zipped = zip(file.events, (0..<file.events.count).map { (i) -> Int in
                    total = total + Int(times[i % times.count])
                    return total
                })
                
                return (name, zipped)
            }
        // Build all the events and the exact time to wait for each one.
        }.enumerated().map { (itemPosition, result) -> Result<[(event: Event, time: DispatchTime)],Error> in
            result.map { (itemName, zipped) in
                let now = DispatchTime.now()
                var previous: StreamerFileSession.SubscriptionUpdate? = nil
                
                return zipped.map { (event, wait) in
                    let time = now + .seconds(wait)
                    switch event {
                    case .lost:
                        return (.lost(count: 1, item: (itemName, itemPosition)), time)
                    case .update(let isSnapShot, let fields):
                        let update = StreamerFileSession.SubscriptionUpdate(item: itemName, snapshot: isSnapShot, fields: fields, previous: previous)
                        previous = update
                        return (.update(update), time)
                    }
                }
            }
        }
        
        // Prepare all variables for subscription.
        let label = IG.Streamer.reverseDNS + ".queue.subscription"
        let queue = DispatchQueue(label: label, qos: .realTimeMessaging, autoreleaseFrequency: .inherit, target: nil)
        let (signal, input) = Signal<Event,Never>.pipe()
        let disposable = signal.observeValues { [weak session = self] (event) in
            guard let session = session else { return }
            
            switch event {
            case .lost(let count, let item):
                session.sendDelegates { $0.updatesLost(count: UInt(count), from: session, item: (item.name, UInt(item.position))) }
            case .update(let update):
                session.sendDelegates { $0.updateReceived(update, from: session) }
            }
        }
        
        // Subscription session variables update.
        self.isSubscribed = true
        self.operation = (queue, signal, disposable)
        
        // Compute all events that will be sent.
        var events: [(event: Event, time: DispatchTime)] = []
        for result in items {
            switch result {
            case .failure(let underlying):
                let error = Streamer.Subscription.Error(code: 777, message: "File subscription failed with error: \(underlying.localizedDescription)")
                self.sendDelegates { $0.subscriptionFailed(to: self, error: error)
                }
            case .success(let value):
                events.append(contentsOf: value)
                self.sendDelegates { $0.subscribed(to: self) }
            }
        }
        
        guard !events.isEmpty else {
            self.operation?.disposable?.dispose()
            self.operation = nil
            self.isSubscribed = false
            self.isActive = false
            return false
        }
        
        for (event, time) in events {
            queue.asyncAfter(deadline: time) { input.send(value: event) }
        }
        
        return true
    }
    
    /// Stops the file subscription and cleans up any subscription state (delegates are not removed, though).
    ///
    /// The subscribed delegates will receive an "unsubscribe" message.
    func stop() {
        self.operation?.disposable?.dispose()
        self.operation = nil
        self.isSubscribed = false
        self.isActive = false
        self.delegatesWeak.clean()
        self.sendDelegates { $0.unsubscribed(to: self) }
    }
    
    /// Sends `action` to every single delegate subscribe to this subscription instance.
    /// - parameter action: The action to be send to the delegate passed as parameter.
    private func sendDelegates(_ action: (StreamerSubscriptionDelegate)->()) {
        guard let delegates = self.delegatesWeak.values as? [StreamerSubscriptionDelegate],
              !delegates.isEmpty else { return }
        
        for delegate in delegates {
            action(delegate)
        }
    }
}

extension StreamerFileSession.SubscriptionSession {
    // Errors that can be raised when running a subscription.
    enum Error: Swift.Error {
        /// The file URL provided is not valid.
        case invalidURL(Any)
        /// The file under the given URL couldn't be parsed.
        case invalidFile(underlying: Swift.Error)
    }
    
    /// Supported event for the subscription.
    enum Event {
        /// Updated values have been received.
        case update(StreamerFileSession.SubscriptionUpdate)
        /// A `count` amount of values have been lost for unknown circumstances.
        case lost(count: Int, item: (name: String, position: Int))
    }
}
