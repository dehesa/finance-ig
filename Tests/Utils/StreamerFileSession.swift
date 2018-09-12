@testable import IG
import Utils
import XCTest

/// Mocked Lightstreamer session that will pick up responses from the bundle's file system.
final class StreamerFileSession: StreamerSession {
    /// Root url for the folder containing the mocked data.
    private let rootURL: URL
    /// Container for all session delegates (only weak bonds).
    private var sessionDelegates = WeakArray<AnyObject>()
    /// Container for all subscription objects.
    public private(set) var subscriptionObjects = [AnyObject]()
    private(set) var status = Streamer.Status.disconnected(isRetrying: false).rawValue

    init(serverAddress: String?, adapterSet: String?) {
        guard let address = serverAddress,
              let url = URL(string: address) else {
            fatalError("A correct file URL needs to be provided. URL provided: \(serverAddress ?? "nil")")
        }

        guard let scheme = Account.SupportedScheme(url: url), case .file = scheme else {
            fatalError("The URL is not of \"file\" type.")
        }

        self.rootURL = url
    }

    var delegates: [Any] {
        return sessionDelegates.values
    }

    func add(delegate: StreamerSessionDelegate) {
        self.sessionDelegates.clean()
        self.sessionDelegates.append(delegate)
    }

    func remove(delegate: StreamerSessionDelegate) {
        self.sessionDelegates.clean()
        self.sessionDelegates.remove(element: delegate)
    }

    func connect() {
        guard self.status == Streamer.Status.disconnected(isRetrying: false).rawValue else { return }
        self.changeStatus(to: .connecting)
        self.changeStatus(to: .connected(.websocket(isPolling: false)))
        self.sessionDelegates.clean()
    }

    func disconnect() {
        self.changeStatus(to: .disconnected(isRetrying: false))
        self.sessionDelegates.clean()
    }
    
    func makeSubscriptionSession<F:StreamerField>(mode: Streamer.Mode, items: Set<String>, fields: Set<F>) -> StreamerSubscriptionSession {
        return StreamerFileSession.SubscriptionSession(mode: mode.rawValue, items: items, fields: Set(fields.map { $0.rawValue }))
    }
    
    var subscriptions: [Any] {
        return self.subscriptionObjects as [Any]
    }

    func subscribe(to subscription: StreamerSubscriptionSession) {
        guard case .none = self.subscriptionObjects.find({ $0 === subscription }) else { return }
        self.subscriptionObjects.append(subscription)
        // If the subscription is already active, the delegate has been added and there is no further work to do.
        guard !subscription.isActive else { return }
        // If the subscription instance is not of file type, there has been a major problem somewhere else.
        guard let subSession = subscription as? StreamerFileSession.SubscriptionSession else {
            fatalError("The subscription session is not a \"file subscription session\"")
        }
        // Send a value every second.
        guard subSession.start(every: [1], rootURL: self.rootURL) else {
            return self.unsubscribe(from: subscription)
        }
    }

    func unsubscribe(from subscription: StreamerSubscriptionSession) {
        guard let location = self.subscriptionObjects.locate({ $0 === subscription }) else { return }
        self.subscriptionObjects.remove(at: location.index)
        
        guard let subSession = subscription as? StreamerFileSession.SubscriptionSession else {
            fatalError("The subscription session is not a \"file subscription session\"")
        }
        subSession.stop()
    }
}

extension StreamerFileSession {
    /// Changes the internal status from the session.
    fileprivate func changeStatus(to status: Streamer.Status) {
        self.status = status.rawValue
        
        for weakDelegate in self.sessionDelegates {
            guard let delegate = weakDelegate,
                  let sessionDelegate = delegate as? StreamerSessionDelegate else { continue }
            sessionDelegate.statusChanged(to: status, on: self)
        }
    }
}
