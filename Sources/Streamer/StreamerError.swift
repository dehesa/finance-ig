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
            var result = ErrorPrint(domain: "Streamer Error")
            
            switch self {
            case .sessionExpired:
                result.title = "Session expired."
                result.append(details: "The underlying Lightstream session or the \(Streamer.self) instance cannot be found. You can probably solve this by creating a strong reference to the \(Streamer.self) instance.")
            case .invalidCredentials(let credentials, let message):
                result.title = "Invalid credentials."
                result.append(details: message)
                result.append(involved: credentials)
            case .invalidRequest(let message):
                result.title = "Invalid request."
                result.append(details: message)
            case .subscriptionFailed(let item, let fields, let error):
                result.title = "Subscription failed."
                result.append(details: "Subscription to: \(item)")
                result.append(details: "Subscriotion fields: \(fields.joined(separator: ", "))")
                result.append(error: error)
            case .invalidResponse(let item, let fields, let message):
                result.title = "Invalid response"
                result.append(details: message)
                result.append(involved: item)
                result.append(involved: fields)
            }
            
            return result.debugDescription
        }
    }
}
