import GRDB
import Foundation

extension IG.Database {
    ///
    public struct Error: IG.Error {
        public let type: Self.Kind
        public internal(set) var message: String
        public internal(set) var suggestion: String
        public internal(set) var underlyingError: Swift.Error?
        public internal(set) var context: [(title: String, value: Any)] = []
        
        internal init(_ type: Self.Kind, _ message: String, suggestion: String, underlying error: Swift.Error? = nil) {
            self.type = type
            self.message = message
            self.suggestion = suggestion
            self.underlyingError = error
        }
        
        /// A factory function for `.sessionExpired` API errors.
        /// - parameter message: A brief explanation on what happened.
        /// - parameter suggestion: A helpful suggestion on how to avoid the error.
        internal static func sessionExpired(message: String = Self.Message.sessionExpired, suggestion: String = Self.Suggestion.keepSession) -> Self {
            self.init(.sessionExpired, message, suggestion: suggestion)
        }
        
        /// A factory function for `.invalidRequest` database errors.
        /// - parameter message: A brief explanation on what happened.
        /// - parameter suggestion: A helpful suggestion on how to avoid the error.
        internal static func invalidRequest(_ message: String, underlying error: Swift.Error? = nil, suggestion: String) -> Self {
            self.init(.invalidRequest, message, suggestion: suggestion, underlying: error)
        }
    }
}

extension IG.Database.Error {
    /// The type of Database error raised.
    public enum Kind: CaseIterable {
        /// The Database instance couldn't be found.
        case sessionExpired
        /// The request parameters given are invalid.
        case invalidRequest
    }
    
    /// Namespace for messages reused over the framework.
    internal enum Message {
        static var sessionExpired: String { "The \(IG.Database.self) instance was not found." }
    }
    
    /// Namespace for suggestions reused over the framework.
    internal enum Suggestion {
        static var keepSession: String { "The \(IG.Database.self) functionality is asynchronous; keep around the \(IG.Database.self) instance while a response hasn't been received." }
    }
}

extension IG.Database.Error: ErrorPrintable {
    var printableDomain: String {
        return "Database Error"
    }
    
    var printableType: String {
        switch self.type {
        case .sessionExpired: return "Session expired"
        case .invalidRequest: return "Invalid request"
        }
    }
    
    public var debugDescription: String {
        var result = self.printableHeader
        
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
