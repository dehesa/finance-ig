import Foundation

extension DispatchQoS {
    /// Quality of Service for real time messaging.
    static let realTimeMessaging = DispatchQoS(qosClass: .userInitiated, relativePriority: 0)
}
