import Foundation
@testable import IG

extension Test.Account {
    /// Error that can be thrown by trying to load an testing account file.
    internal struct Error: IG.Error {
        /// The type of API error.
        let type: Self.Kind
        /// A message accompaigning the error explaining what happened.
        var message: String
        /// Possible solutions for the problem.
        var suggestion: String
        /// Any underlying error that was raised right before this hosting error.
        var underlyingError: Swift.Error? = nil
        /// Store values/objects that gives context to the hosting error.
        var context: [(title: String, value: Any)] = []
        
        static func environmentVariableNotFound(key: String) -> Self {
            let num = "\(Self.prefix)\t"
            let message = #"The target environment key "\#(key)" doesn't seem to be set."#
            let suggestion = #"If you are running the tests through the Command line, remember to add an environment variable when running the test command. If you are running the tests with Xcode\#(num)1. Edit the "IG" scheme.\#(num)2. Select the "Test" section.\#(num)3. Select the "Arguments" tab.\#(num)4. Add an environment variable with key "\#(key)" and the value as the location JSON file with the test account data (e.g. "file://Environment/mocked.json").\#(num)5. Be sure to have the filled JSON account on that location."#
            return self.init(type: .environmentVariableNotFound, message: message, suggestion: suggestion)
        }
        
        static func invalidURL(_ path: String) -> Self {
            let message = (path.isEmpty) ? "The targeted URL is empty" : #"The URL path is "\#(path)""#
            let suggestion = "The given URL was invalid. Review it carefully."
            return self.init(type: .invalidURL, message: message, suggestion: suggestion)
        }
        
        static func bundleResourcesNotFound() -> Self {
            let message = #"The test Bundle resources (i.e. "bundle.resourceURL" couldn't be loaded."#
            let suggestion = "Please contact the repository maintainer."
            return self.init(type: .bundleResourcesNotFound, message: message, suggestion: suggestion)
        }
        
        static func dataLoadFailed(url: URL, underlyingError error: Swift.Error) -> Self {
            let message = #"The file with URL "\#(url.absoluteString)" couldn't be loaded through "Data(contentsOf:)"."#
            let suggestion = "Review the URL and be sure there is a JSON file under that path."
            return self.init(type: .dataLoadFailed, message: message, suggestion: suggestion, underlyingError: error)
        }
        
        static func accountParsingFailed(url: URL, underlyingError error: Swift.Error) -> Self {
            let message = #"An error was encountered decoding the Test Account JSON file at "\#(url.absoluteString)"."#
            let suggestion = "Be sure the JSON file is valid and review the underlying error."
            return self.init(type: .accountParsingFailed, message: message, suggestion: suggestion, underlyingError: error)
        }
    }
}

//result.append(details: "File URL: \(url.absoluteString)")


extension Test.Account.Error {
    /// The type of API error raised.
    public enum Kind: CaseIterable {
        /// The environment key passed as parameter was not found on the environment variables.
        case environmentVariableNotFound
        /// The URL given in the file is invalid or none existant
        case invalidURL
        /// The bundle resource path couldn't be found.
        case bundleResourcesNotFound
        /// The account file couldn't be retrieved.
        case dataLoadFailed
        /// The account failed couldn't be parsed.
        case accountParsingFailed
    }
}

extension Test.Account.Error: ErrorPrintable {
    var printableDomain: String {
        return "Test Error"
    }
    
    var printableType: String {
        switch self.type {
        case .environmentVariableNotFound: return "Environment variable key not found."
        case .invalidURL: return "Invald URL."
        case .bundleResourcesNotFound: return "Bundle resources not found."
        case .dataLoadFailed: return "Data load failed."
        case .accountParsingFailed: return "Account parsing failed."
        }
    }
    
    public var debugDescription: String {
        var result = self.printableHeader
        
        if let underlyingString = self.printableUnderlyingError {
            result.append(underlyingString)
        }
        
        if let contextString = self.printableContext {
            result.append(contextString)
        }
        
        result.append("\n")
        return result
    }
}
