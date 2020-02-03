import Foundation

extension IG.Streamer {
    /// List of errors that can be generated throught the Streamer class.
    public struct Error: IG.Error {
        public let type: Self.Kind
        public internal(set) var message: String
        public internal(set) var suggestion: String
        public internal(set) var underlyingError: Swift.Error?
        public internal(set) var context: [Self.Item] = []
        /// The subscription item.
        public internal(set) var item: String?
        /// The subscription fields.
        public internal(set) var fields: [String]?
        
        /// Designated initializer, filling all required error fields.
        /// - parameter type: The error type.
        /// - parameter message: A brief explanation on what happened.
        /// - parameter suggestion: A helpful suggestion on how to avoid the error.
        /// - parameter item: The Lightstreamer subscription item.
        /// - parameter fields: The Lightstreamer subscription fields associated for the previous item.
        /// - parameter error: The underlying error that happened right before this error was created.
        internal init(_ type: Self.Kind, _ message: String, suggestion: String, item: String? = nil, fields: [String]? = nil, underlying error: Swift.Error? = nil) {
            self.type = type
            self.message = message
            self.item = item
            self.fields = fields
            self.underlyingError = error
            self.suggestion = suggestion
        }
        
        /// Wrap the argument error in a `Streamer` error.
        /// - parameter error: Swift error to be wrapped.
        static func transform(_ error: Swift.Error) -> Self {
            switch error {
            case let e as Self: return e
            case let e: return .unknown(message: "An unknown error has occurred", underlyingError: e, suggestion: .reviewError)
            }
        }
    }
}

extension IG.Streamer.Error {
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
        /// Unknown (not recognized) error.
        case unknown
    }
    
    /// A factory function for `.sessionExpired` Streamer errors.
    /// - parameter message: A brief explanation on what happened.
    /// - parameter suggestion: A helpful suggestion on how to avoid the error.
    internal static func sessionExpired(message: Self.Message = .sessionExpired, suggestion: Self.Suggestion = .keepSession) -> Self {
        self.init(.sessionExpired, message.rawValue, suggestion: suggestion.rawValue)
    }
    
    /// A factory function for `.invalidRequest` Streamer errors.
    /// - parameter message: A brief explanation on what happened.
    /// - parameter error: The underlying error that is the source of the error being initialized.
    /// - parameter suggestion: A helpful suggestion on how to avoid the error.
    internal static func invalidRequest(_ message: Self.Message, underlying error: Swift.Error? = nil, suggestion: Self.Suggestion) -> Self {
        self.init(.invalidRequest, message.rawValue, suggestion: suggestion.rawValue, underlying: error)
    }
    
    /// A factory function for `.subscriptionFailed` Streamer errors.
    /// - parameter message: A brief explanation on what happened.
    /// - parameter error: The underlying error that is the source of the error being initialized.
    /// - parameter suggestion: A helpful suggestion on how to avoid the error.
    internal static func subscriptionFailed(_ message: Self.Message, item: String, fields: [String], underlying error: Swift.Error? = nil, suggestion: Self.Suggestion) -> Self {
        self.init(.subscriptionFailed, message.rawValue, suggestion: suggestion.rawValue, item: item, fields: fields, underlying: error)
    }
    
    /// A factory function for `.invalidResponse` Streamer errors.
    /// - parameter message: A brief explanation on what happened.
    /// - parameter error: The underlying error that is the source of the error being initialized.
    /// - parameter suggestion: A helpful suggestion on how to avoid the error.
    internal static func invalidResponse(_ message: Self.Message, item: String, update: IG.Streamer.Packet, underlying error: Swift.Error? = nil, suggestion: Self.Suggestion) -> Self {
        let fields = update.keys.map { $0 }
        var error = self.init(.invalidResponse, message.rawValue, suggestion: suggestion.rawValue, item: item, fields: fields, underlying: error)
        error.context.append(("Update", update))
        return error
    }
    
    /// A factory function for `.unknown` Streamer errors.
    /// - parameter message: A brief explanation on what happened.
    /// - parameter error: The underlying error that happened right before this error was created.
    /// - parameter suggestion: A helpful suggestion on how to avoid the error.
    internal static func unknown(message: Self.Message, underlyingError error: Swift.Error, suggestion: Self.Suggestion) -> Self {
        self.init(.unknown, message.rawValue, suggestion: suggestion.rawValue, underlying: error)
    }
}

extension IG.Streamer.Error {
    /// Namespace for messages reused over the framework.
    internal struct Message: IG.ErrorNameSpace {
        let rawValue: String; init(_ trustedValue: String) { self.rawValue = trustedValue }
        
        static var sessionExpired: Self { "The Streamer instance was not found" }
        static var noCredentials: Self  { "No credentials were found on the Streamer instance" }
        static var unknownParsing: Self { "An unknown error occur while parsing a subscription update" }
        static func parsing(update error: IG.Streamer.Formatter.Update.Error) -> Self {
            .init(#"An error was encountered when parsing the value "\#(error.value)" from a "String" to a "\#(error.type)" type"#)
        }
    }
    
    /// Namespace for suggestions reused over the framework.
    internal struct Suggestion: IG.ErrorNameSpace {
        let rawValue: String; init(_ trustedValue: String) { self.rawValue = trustedValue }
        
        static var keepSession: Self { "The Streamer functionality is asynchronous; keep around the Streamer instance while a response hasn't been received" }
        static var reviewError: Self { .init(IG.API.Error.Suggestion.reviewError.rawValue) }
        static var fileBug: Self     { .init(IG.API.Error.Suggestion.fileBug.rawValue) }
    }
}

extension IG.Streamer.Error: IG.ErrorPrintable {
    internal static var printableDomain: String {
        return "\(IG.Streamer.printableDomain).\(Self.self)"
    }
    
    internal var printableType: String {
        switch self.type {
        case .sessionExpired: return "Session expired"
        case .invalidRequest: return "Invalid request"
        case .subscriptionFailed: return "Subscription failed"
        case .invalidResponse: return "Invalid response"
        case .unknown:         return "Unknown"
        }
    }
    
    internal func printableMultiline(level: Int) -> String {
        let levelPrefix    = Self.debugPrefix(level: level+1)
        let sublevelPrefix = Self.debugPrefix(level: level+2)
        
        var result = "\(Self.printableDomain) (\(self.printableType))"
        result.append("\(levelPrefix)Error message: \(self.message)")
        result.append("\(levelPrefix)Suggestions: \(self.suggestion)")
        
        if let item = self.item {
            result.append("\(levelPrefix)Subscription item: \(item)")
        }
        
        if let fields = self.fields {
            result.append("\(levelPrefix)Subscription fields: [\(fields.joined(separator: ", "))]")
        }
        
        if !self.context.isEmpty {
            result.append("\(levelPrefix)Error context: \(IG.ErrorHelper.representation(of: self.context, itemPrefix: sublevelPrefix, maxCharacters: Self.maxCharsPerLine))")
        }
        
        let errorStr = "\(levelPrefix)Underlying error: "
        if let errorRepresentation = IG.ErrorHelper.representation(of: self.underlyingError, level: level, prefixCount: errorStr.count, maxCharacters: Self.maxCharsPerLine) {
            result.append(errorStr)
            result.append(errorRepresentation)
        }
        
        return result
    }
}
