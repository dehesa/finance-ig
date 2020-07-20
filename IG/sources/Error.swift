import Foundation

/// Errors thrown by the IG framework.
public final class Error: LocalizedError, CustomNSError, CustomDebugStringConvertible {
    /// The internal error type.
    private let type: Error.Failure
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
    internal init(_ type: Error.Failure, _ reason: String? = nil, help: String? = nil, underlying: Swift.Error? = nil, info: [String:Any] = [:]) {
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
        self.type.rawValue
    }
    
    public var errorDescription: String? {
        self.type.description
    }
    
    public var localizedDescription: String {
        var result = "\(self.type.description)"
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
    
    /// IG error domains.
    enum Failure {
        case api(API.Failure)
        case streamer(Streamer.Failure)
        case database(Database.Failure)
    }
}

// MARK: -

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
        case sessionExpired  = 201
        /// The request parameters are invalid.
        case invalidRequest  = 202
        /// A URL request was executed, but an error was returned by low-level layers.
        case subscriptionFailed = 203
        /// The received response was invalid.
        case invalidResponse = 204
    }
}

internal extension Database {
    /// The list of possible failures occurring in the Database.
    enum Failure: Int {
        case unknown = 300
    }
}

extension Error.Failure: RawRepresentable, CustomStringConvertible {
    init?(rawValue: Int) {
        if let failure = API.Failure(rawValue: rawValue) {
            self = .api(failure)
        } else if let failure = Streamer.Failure(rawValue: rawValue) {
            self = .streamer(failure)
        } else if let failure = Database.Failure(rawValue: rawValue) {
            self = .database(failure)
        } else {
            return nil
        }
    }
    
    var rawValue: Int {
        switch self {
        case .api(let f): return f.rawValue
        case .streamer(let f): return f.rawValue
        case .database(let f): return f.rawValue
        }
    }
    
    var description: String {
        switch self {
        case .api(let f): return "[API] \(f.description)"
        case .streamer(let f): return "[Streamer] \(f.description)"
        case .database(let f): return "[Database] \(f.description)"
        }
    }
}

extension API.Failure: CustomStringConvertible {
    var description: String {
        switch self {
        case .sessionExpired: return "Session expired."
        case .invalidRequest: return "Invalid request."
        case .callFailed: return "Call failed."
        case .invalidResponse: return "Invalid response."
        }
    }
}

extension Streamer.Failure: CustomStringConvertible {
    var description: String {
        switch self {
        case .sessionExpired: return "Session expired."
        case .invalidRequest: return "Invalid request."
        case .subscriptionFailed: return "Subscription failed."
        case .invalidResponse: return "Invalid response."
        }
    }
}

extension Database.Failure: CustomStringConvertible {
    var description: String {
        switch self {
        case .unknown: return "Unknown error."
        }
    }
}

// MARK: -

/// Forces a cast from the generic Swift error to the framework error.
func errorCast(from error: Swift.Error) -> IG.Error {
    error as! IG.Error
}
