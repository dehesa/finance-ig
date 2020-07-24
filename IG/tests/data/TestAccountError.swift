import Foundation
@testable import IG

extension Test.Account {
    /// Error that can be thrown by trying to load an testing account file.
    internal final class Error: LocalizedError, CustomNSError, CustomDebugStringConvertible {
        private let type: Kind
        let failureReason: String?
        var recoverySuggestion: String? = nil
        let helpAnchor: String?
        var errorUserInfo: [String:Any] = [:]
        let underlyingError: Swift.Error?
        
        /// Designated initializer, filling all required error fields.
        /// - parameter type: The error type.
        /// - parameter reason: A brief explanation on what happened.
        /// - parameter help: A helpful suggestion on how to avoid the error.
        /// - parameter error: The underlying error that happened right before this error was created.
        init(_ type: Kind, _ reason: String, help: String, underlying error: Swift.Error? = nil) {
            self.type = type
            self.failureReason = reason
            self.helpAnchor = help
            self.underlyingError = error
        }
    }
}

//result.append(details: "File URL: \(url.absoluteString)")
extension Test.Account.Error {
    /// The type of API error raised.
    enum Kind: Int, Hashable {
        /// The environment key passed as parameter was not found on the environment variables.
        case environmentVariableNotFound = 1
        /// The URL given in the file is invalid or none existant
        case invalidURL
        /// The bundle resource path couldn't be found.
        case bundleResourcesNotFound
        /// The account file couldn't be retrieved.
        case dataLoadFailed
        /// The account failed couldn't be parsed.
        case accountParsingFailed
    }
    
    static var errorDomain: String {
        Bundle.IG.name + "\(Bundle.IG.name).\(Test.self).\(Test.Account.self).\(Test.Account.Error.self)"
    }
    
    var errorCode: Int {
        self.type.rawValue
    }
    
    var errorDescription: String? {
        var result = "[Test] "
        switch self.type {
        case .environmentVariableNotFound: result.append("Environment variable key not found.")
        case .invalidURL: result.append("Invald URL.")
        case .bundleResourcesNotFound: result.append("Bundle resources not found.")
        case .dataLoadFailed: result.append("Data load failed.")
        case .accountParsingFailed: result.append("Account parsing failed.")
        }
        return result
    }
    
    public var localizedDescription: String {
        var result = "\(self.errorDescription!)"
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
