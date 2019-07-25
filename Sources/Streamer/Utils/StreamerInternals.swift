import Foundation

extension DispatchQoS {
    /// Quality of Service for real time messaging.
    internal static let realTimeMessaging = DispatchQoS(qosClass: .userInitiated, relativePriority: 0)
}
