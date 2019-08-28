import Foundation

extension Streamer {
    /// List of errors that can be generated throught the Streamer class.
    public struct Error: IG.Error {
        public let type: Self.Kind
        public internal(set) var message: String
        public internal(set) var suggestion: String
        public internal(set) var underlyingError: Swift.Error?
        public internal(set) var context: [(title: String, value: Any)] = []
        /// The subscription item.
        public internal(set) var item: String?
        /// The subscription fields.
        public internal(set) var fields: [String]?
        
        /// Designated initializer, filling all required error fields.
        /// - parameter type: The error type.
        /// - parameter message: A brief explanation on what happened.
        /// - parameter suggestion: A helpful suggestion on how to avoid the error.
        /// - parameter error: The underlying error that happened right before this error was created.
        internal init(_ type: Self.Kind, _ message: String, suggestion: String, item: String? = nil, fields: [String]? = nil, underlying error: Swift.Error? = nil) {
            self.type = type
            self.message = message
            self.item = item
            self.fields = fields
            self.underlyingError = error
            self.suggestion = suggestion
        }
        
        /// A factory function for `.sessionExpired` API errors.
        /// - parameter message: A brief explanation on what happened.
        /// - parameter suggestion: A helpful suggestion on how to avoid the error.
        internal static func sessionExpired(message: String = Self.Message.sessionExpired, suggestion: String = Self.Suggestion.keepSession) -> Self {
            self.init(.sessionExpired, message, suggestion: suggestion)
        }
        
        /// A factory function for `.invalidRequest` API errors.
        /// - parameter message: A brief explanation on what happened.
        /// - parameter suggestion: A helpful suggestion on how to avoid the error.
        internal static func invalidRequest(_ message: String, underlying error: Swift.Error? = nil, suggestion: String) -> Self {
            self.init(.invalidRequest, message, suggestion: suggestion, underlying: error)
        }
        
        /// A factory function for `.subscriptionFailed` API errors.
        /// - parameter message: A brief explanation on what happened.
        /// - parameter suggestion: A helpful suggestion on how to avoid the error.
        internal static func subscriptionFailed(_ message: String, item: String, fields: [String], underlying error: Swift.Error? = nil, suggestion: String) -> Self {
            self.init(.subscriptionFailed, message, suggestion: suggestion, item: item, fields: fields, underlying: error)
        }
        
        /// A factory function for `.invalidResponse` API errors.
        /// - parameter message: A brief explanation on what happened.
        /// - parameter suggestion: A helpful suggestion on how to avoid the error.
        internal static func invalidResponse(_ message: String, item: String, update: [String:Streamer.Subscription.Update], underlying error: Swift.Error? = nil, suggestion: String) -> Self {
            let fields = update.keys.map { $0 }
            var error = self.init(.invalidResponse, message, suggestion: suggestion, item: item, fields: fields, underlying: error)
            error.context.append(("Update", update))
            return error
        }
    }
}

extension Streamer.Error {
    /// The type of Streamer error raised.
    public enum Kind: CaseIterable {
        /// The streaming session has expired
        case sessionExpired
        /// The request parameters are invalid.
        case invalidRequest
        /// A URL request was executed, but an error was returned by low-level layers.
        case subscriptionFailed
        /// The received response was invalid.
        case invalidResponse
    }
    
    /// Namespace for messages reused over the framework.
    internal enum Message {
        static var sessionExpired: String { "The Streamer instance was not found." }
        static var noCredentials: String { "No credentials were found on the Streamer instance." }
        static var unknownParsing: String { "An unknown error occur while parsing a subscription update." }
        static func parsing(update error: Streamer.Formatter.Update.Error) -> String {
            #"An error was encountered when parsing the value "\#(error.value)" from a "String" to a "\#(error.type)" type."#
        }
    }
    
    /// Namespace for suggestions reused over the framework.
    internal enum Suggestion {
        static var keepSession: String { "The Streamer functionality is asynchronous; keep around the Streamer instance while a response hasn't been received." }
        static var bug: String { API.Error.Suggestion.bug }
        static var reviewError: String { "Review the returned error and try to fix the problem." }
    }
}

extension Streamer.Error: ErrorPrintable {
    var printableDomain: String {
        return "Streamer Error"
    }
    
    var printableType: String {
        switch self.type {
        case .sessionExpired: return "Session expired"
        case .invalidRequest: return "Invalid request"
        case .subscriptionFailed: return "Subscription failed"
        case .invalidResponse: return "Invalid response"
        }
    }
    
    public var debugDescription: String {
        var result = self.printableHeader
        
        if let item = self.item {
            result.append("\(Self.prefix)Subscription item: \(item)")
        }
        
        if let fields = self.fields {
            result.append("\(Self.prefix)Subscription fields: [\(fields.joined(separator: ", "))]")
        }
        
        if let contextString = self.printableContext {
            result.append(contextString)
        }
        
        if let underlyingString = self.printableUnderlyingError {
            result.append(underlyingString)
        }
        
        result.append("\n\n")
        return result
    }
}
