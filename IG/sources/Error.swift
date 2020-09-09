import Foundation

/// Errors thrown by the IG framework.
public final class Error: LocalizedError, CustomNSError, CustomDebugStringConvertible {
    /// The internal error type.
    private let type: Failure
    /// A localized message describing the reason for the failure.
    public let failureReason: String?
    /// A localized message describing how one might recover from the failure.
    public let recoverySuggestion: String?
    /// A localized message providing "help" text if the user requests help.
    public let helpAnchor: String?
    /// Any further context given needed information to debug the error.
    public internal(set) var errorUserInfo: [String:Any]
    /// Any underlying error that cascade into this error.
    public let underlyingError: Swift.Error?
    
    /// Designated initializer.
    internal init(_ type: Failure, _ reason: String? = nil, help: String? = nil, underlying: Swift.Error? = nil, info: [String:Any] = [:]) {
        self.type = type
        self.failureReason = reason
        self.recoverySuggestion = nil
        self.helpAnchor = help
        self.errorUserInfo = info
        self.underlyingError = underlying
    }
    
    public static var errorDomain: String {
        Bundle.IG.name + ".Error"
    }
    
    public var errorCode: Int {
        self.type.code
    }
    
    public var errorDescription: String? {
        var result: String
        
        switch self.type {
        case .api(let f):
            result = "[API] "
            switch f {
            case .sessionExpired: result.append("Session expired.")
            case .invalidRequest: result.append("Invalid request.")
            case .callFailed: result.append("Call failed.")
            case .invalidResponse: result.append("Invalid response.")
            }
        case .streamer(let f):
            result = "[Streamer] "
            switch f {
            case .sessionExpired: result.append("Session expired.")
            case .invalidRequest: result.append("Invalid request.")
            case .subscriptionFailed: result.append("Subscription failed.")
            case .invalidResponse: result.append("Invalid response.")
            }
        case .database(let f):
            result = "[Database] "
            switch f {
            case .sessionExpired: result.append("Session expired.")
            case .invalidRequest: result.append("Invalid request.")
            case .callFailed: result.append("Call failed.")
            case .invalidResponse: result.append("Invalid response.")
            }
        }
        
        return result
    }
    
    public var localizedDescription: String {
        var result = "\(self.errorDescription.unsafelyUnwrapped)"
        if let reason = self.failureReason {
            result.append("\n\tReason: \(reason)")
        }
        if let recovery = self.recoverySuggestion {
            result.append("\n\tRecovery: \(recovery)")
        }
        if let help = self.helpAnchor {
            result.append("\n\tHelp: \(help)")
        }
        if !self.errorUserInfo.isEmpty {
            result.append("\n\tUser info: ")
            result.append(self.errorUserInfo.map { "\($0): \($1)" }.joined(separator: ", "))
        }
        if let error = self.underlyingError {
            result.append("\n\tUnderlying error: \(error)")
        }
        return result
    }
    
    public var debugDescription: String {
        return self.localizedDescription
    }
}

// MARK: -

internal extension IG.Error {
    /// IG error domains.
    enum Failure: Hashable {
        case api(API.Failure)
        case streamer(Streamer.Failure)
        case database(Database.Failure)
    }
}

internal extension API {
    /// The list of possible failures occurring in the API.
    enum Failure: Int {
        /// The streaming session has expired.
        case sessionExpired = 101
        /// The request parameters are invalid.
        case invalidRequest = 102
        /// The HTTP call failed.
        case callFailed = 103
        /// The received response was invalid.
        case invalidResponse = 104
    }
}

internal extension Streamer {
    /// The list of possible failures occurring in the Streamer.
    enum Failure: Int {
        /// The streaming session has expired.
        case sessionExpired = 201
        /// The request parameters are invalid.
        case invalidRequest = 202
        /// A URL request was executed, but an error was returned by low-level layers.
        case subscriptionFailed = 203
        /// The received response was invalid.
        case invalidResponse = 204
    }
}

internal extension Database {
    /// The list of possible failures occurring in the Database.
    enum Failure: Int {
        /// The Database instance couldn't be found.
        case sessionExpired = 301
        /// The request parameters given are invalid.
        case invalidRequest = 302
        /// A database request was executed, but an error was returned by low-level layers.
        case callFailed = 303
        /// The fetched response from the database is invalid.
        case invalidResponse = 304
    }
}

internal extension IG.Error.Failure {
    var code: Int {
        switch self {
        case .api(let f): return f.rawValue
        case .streamer(let f): return f.rawValue
        case .database(let f): return f.rawValue
        }
    }
}

/// Forces a cast from the generic Swift error to the framework error.
@usableFromInline func errorCast(from error: Swift.Error) -> IG.Error {
    error as! IG.Error
}
