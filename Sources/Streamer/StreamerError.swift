import Foundation

extension Streamer {
    /// List of errors that can be generated throught the Streamer class.
    public enum Error: Swift.Error, CustomDebugStringConvertible {
        /// The Streaming session expired.
        case sessionExpired
        /// The passed credentials are not of the expected form.
        case invalidCredentials(API.Credentials?, message: String)
        /// The request parameters are invalid.
        case invalidRequest(message: String)
        /// The subscription failed to established or it was abrouptly disconnected.
        case subscriptionFailed(to: String, fields: [String], error: Swift.Error?)
        /// A streaming response was invalid or couldn't be parsed.
        case invalidResponse(item: String?, fields: [AnyHashable:Any], message: String)
        
        public var debugDescription: String {
            var result = "\n\n"
            result.append("[Streamer Error]")
            
            switch self {
            case .sessionExpired:
                result.addTitle("The session has expired.")
                result.addDetail("The underlying Lightstream session or the \(Streamer.self) instance cannot be found. You can probably solve this by creating a strong reference to the \(Streamer.self) instance.")
            case .invalidCredentials(let credentials, let message):
                result.addTitle(message)
                result.addDetail(credentials) { "credentials: \($0)" }
            case .invalidRequest(let message):
                result.addTitle(message)
            case .subscriptionFailed(let item, let fields, let error):
                result.addTitle("Subscription to \"\(item)\" failed or was interrupted.")
                result.addDetail("Fields: \(fields.joined(separator: ", "))")
                result.addDetail(error) { "Error: \($0)" }
            case .invalidResponse(let item, let fields, let message):
                result.addTitle(message)
                result.addDetail(item) { "Item name: \($0)" }
                result.addDetail("Content: \(fields)")
            }
            
            result.append("\n\n")
            return result
        }
    }
}
