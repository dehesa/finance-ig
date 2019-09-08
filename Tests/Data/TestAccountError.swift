import Foundation
@testable import IG

extension Test.Account {
    /// Error that can be thrown by trying to load an testing account file.
    internal struct Error: IG.Error {
        let type: Self.Kind
        var message: String
        var suggestion: String
        var underlyingError: Swift.Error? = nil
        var context: [Self.Item] = []
        
        /// Designated initializer, filling all required error fields.
        /// - parameter type: The error type.
        /// - parameter message: A brief explanation on what happened.
        /// - parameter suggestion: A helpful suggestion on how to avoid the error.
        /// - parameter error: The underlying error that happened right before this error was created.
        private init(_ type: Self.Kind, _ message: String, suggestion: String, underlying error: Swift.Error? = nil) {
            self.type = type
            self.message = message
            self.underlyingError = error
            self.suggestion = suggestion
        }
    }
}

//result.append(details: "File URL: \(url.absoluteString)")
extension Test.Account.Error {
    /// The type of API error raised.
    enum Kind: CaseIterable {
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
    
    static func environmentVariableNotFound(key: String) -> Self {
        let message = #"The target environment key "\#(key)" doesn't seem to be set."#
        let suggestion = #"If you are running the tests through the Command line, remember to add an environment variable when running the test command. If you are running the tests with Xcode: 1. Edit the "IG" scheme. 2. Select the "Test" section. 3. Select the "Arguments" tab. 4. Add an environment variable with key "\#(key)" and the value as the location JSON file with the test account data (e.g. "file://Environment/mocked.json"). 5. Be sure to have the filled JSON account on that location."#
        return self.init(.environmentVariableNotFound, message, suggestion: suggestion)
    }
    
    static func invalidURL(_ path: String) -> Self {
        let message = (path.isEmpty) ? "The targeted URL is empty" : #"The URL path is "\#(path)""#
        let suggestion = "The given URL was invalid. Review it carefully."
        return self.init(.invalidURL, message, suggestion: suggestion)
    }
    
    static func bundleResourcesNotFound() -> Self {
        let message = #"The test Bundle resources (i.e. "bundle.resourceURL" couldn't be loaded."#
        let suggestion = "Please contact the repository maintainer."
        return self.init(.bundleResourcesNotFound, message, suggestion: suggestion)
    }
    
    static func dataLoadFailed(url: URL, underlyingError error: Swift.Error) -> Self {
        let message = #"The file with URL "\#(url.absoluteString)" couldn't be loaded through "Data(contentsOf:)"."#
        let suggestion = "Review the URL and be sure there is a JSON file under that path."
        return self.init(.dataLoadFailed, message, suggestion: suggestion, underlying: error)
    }
    
    static func accountParsingFailed(url: URL, underlyingError error: Swift.Error) -> Self {
        let message = #"An error was encountered decoding the Test Account JSON file at "\#(url.absoluteString)"."#
        let suggestion = "Be sure the JSON file is valid and review the underlying error."
        return self.init(.accountParsingFailed, message, suggestion: suggestion, underlying: error)
    }
}

extension Test.Account.Error: IG.ErrorPrintable {
    var printableDomain: String {
        return "IG.\(Test.self).\(Test.Account.self).\(Test.Account.Error.self)"
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
    
    func printableMultiline(level: Int) -> String {
        let levelPrefix    = Self.debugPrefix(level: level+1)
        let sublevelPrefix = Self.debugPrefix(level: level+2)
        
        var result = "\(self.printableDomain) (\(self.printableType))"
        result.append("\(levelPrefix)Error message: \(self.message)")
        result.append("\(levelPrefix)Suggestions: \(self.suggestion)")
        
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
