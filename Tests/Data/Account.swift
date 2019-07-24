import Foundation
@testable import IG

/// Structure containing the loging information for the testing environment.
struct Account: Decodable {
    /// The target account identifier.
    var accountId: String
    /// List of variables required to connect to the API.
    var api: Account.API
    /// List of variables required to connect to the Streamer.
    ///
    /// If `nil`, the credentials are queried to the API (whether mocked or real).
    var streamer: Account.Streamer
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.accountId = try container.decode(String.self, forKey: .accountId)
        self.api = try container.decode(Account.API.self, forKey: .api)
        self.streamer = try container.decodeIfPresent(Account.Streamer.self, forKey: .streamer) ?? Account.Streamer()
    }
    
    private enum CodingKeys: String, CodingKey {
        case accountId, api, streamer
    }
}

extension Account {
    /// Account test environment API information.
    struct API: Decodable {
        /// The root URL from where to call the endpoints.
        ///
        /// If this references a folder in the bundles file system, it shall be of type:
        /// ```
        /// file://API
        /// ```
        var url: URL
        /// The API API key used to identify the developer.
        var key: String
        /// The username identifying the user.
        var username: String
        /// The password allowing access to user data.
        var password: String
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let url = try container.decodeIfPresent(String.self, forKey: .url)
            self.url = try Account.parse(path: url)
            self.key = try container.decode(String.self, forKey: .key)
            self.username = try container.decode(String.self, forKey: .username)
            self.password = try container.decode(String.self, forKey: .password)
        }
        
        private enum CodingKeys: String, CodingKey {
            case url, key, username, password
        }
    }
}

extension Account {
    /// Account test environment Streamer information.
    struct Streamer: Decodable {
        /// The root URL from where to get the streaming messages.
        ///
        /// It can be one of the followings:
        /// - a forlder in the test bundle file system (e.g. `file://Streamer`).
        /// - a https URL (e.g. `https://demo-apd.marketdatasystems.com`).
        /// - `nil`, in which case, the API will be asked for the rootURL.
        var url: URL?
        /// The username/identifier to use as the Streamer credential.
        ///
        /// If `nil`, the API will be queried.
        var username: String?
        /// The password to use as the Streamer credentail.
        ///
        /// If `nil`, the API will be queried.
        var password: String?
        
        fileprivate init() {
            self.url = nil
            self.username = nil
            self.password = nil
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if let url = try container.decodeIfPresent(String.self, forKey: .url) {
                self.url = try Account.parse(path: url)
            } else {
                self.url = nil
            }
            self.username = try container.decodeIfPresent(String.self, forKey: .username)
            if let password = try? container.decode(String.self, forKey: .password) {
                self.password = password
            } else if let credentials = try container.decodeIfPresent(Credentials.self, forKey: .password) {
//                self.password = IG.Streamer.Credentials.password(fromCST: credentials.cst, security: credentials.security)
                /// - todo: Uncomment later and delete the followng line.
                self.password = nil
            } else {
                self.password = nil
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case url, username, password
        }
        
        /// Credentials to be used in the Streamer priviledge authentication.
        private struct Credentials: Decodable {
            /// The certificate secret.
            let cst: String
            /// The security header secret.
            let security: String
        }
    }
}

extension Account {
    /// Supported URL schemes for the rootURL
    enum SupportedScheme: String {
        case file
        case https
        
        init?(url: URL) {
            guard let urlScheme = url.scheme,
                  let result = SupportedScheme(rawValue: urlScheme) else { return nil }
            self = result
        }
    }
    
    /// Error that can be thrown by trying to load an testing account file.
    private enum Error: Swift.Error, CustomDebugStringConvertible {
        /// The environment key passed as parameter was not found on the environment variables.
        case environmentVariableNotFound(key: String)
        /// The URL given in the file is invalid or none existant
        case invalidURL(String?)
        /// The bundle resource path couldn't be found.
        case bundleResourcesNotFound
        /// The account file couldn't be retrieved.
        case dataLoadFailed(url: URL, underlyingError: Swift.Error)
        /// The account failed couldn't be parsed.
        case accountParsingFailed(url: URL, underlyingError: Swift.Error)
        
        var debugDescription: String {
            var result = "\n\n"
            result.append("[Test Error]")
            
            switch self {
            case .environmentVariableNotFound(let key):
                result.addTitle("The variable with name \"\(key)\" hasn't been found in the test environment.")
                result.addDetail("Please set a test environment variable with name \"\(key)\" and value \"file://myrelative/path/from/bundle/resource/folder/myfile.json\".")
                result.addDetail("The JSON file specifies the account used for testing (for more information, check \"\(Account.self).swift\".")
            case .invalidURL(let path):
                result.addTitle("A URL couldn't be formed from: \"\(path ?? "nil")\".")
            case .bundleResourcesNotFound:
                result.addTitle("The test framework resource folder couldn't be found.")
            case .dataLoadFailed(let url, let underlyingError):
                result.addTitle("The file with URL \"\(url.absoluteString)\" couldn't be load.")
                result.addDetail("Underlying error: \(underlyingError)")
            case .accountParsingFailed(let url, let underlyingError):
                result.addTitle("The file with URL \"\(url.absoluteString)\" couldn't be parsed as \"\(Account.self)\" type.")
                result.addDetail("Underlying error: \(underlyingError)")
            }
            
            result.append("\n\n")
            return result
        }
    }
}

extension Account {
    /// Load data to use as testing account/environment.
    /// - parameter environmentKey: Build variable key, which value gives the location of the account swift file.
    /// - returns: Representation of the account file.
    static func make(from environmentKey: String) -> Account {
        guard let accountPath = ProcessInfo.processInfo.environment[environmentKey] else {
            fatalError(Error.environmentVariableNotFound(key: environmentKey).debugDescription)
        }
        
        let accountFileURL: URL
        do {
            accountFileURL = try Account.parse(path: accountPath)
        } catch let error as Account.Error {
            fatalError(error.debugDescription)
        } catch {
            fatalError("Error couldn't be identified.")
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: accountFileURL)
        } catch let error {
            fatalError(Error.dataLoadFailed(url: accountFileURL, underlyingError: error).debugDescription)
        }
        
        do {
            return try JSONDecoder().decode(Account.self, from: data)
        } catch let error {
            fatalError(Error.accountParsingFailed(url: accountFileURL, underlyingError: error).debugDescription)
        }
    }
    
    /// Parse a URL represented as a string into a proper URL.
    ///
    /// If `path` is a relative file path; that path is appended to the test bundle resource URL.
    ///
    /// In the following scenarios, this function will throw an error:
    /// - if `path` is `nil`,
    /// - if `path` doesn't have a scheme (e.g. `https://`) or the scheme is not supported,
    /// - if `path` is empty after the scheme,
    /// - parameter path: A string representing a local or remote URL.
    /// - throws: `Account.Error` type.
    fileprivate static func parse(path: String?) throws -> URL {
        // If no parameter has been provided.
        guard let string = path else {
            throw Account.Error.invalidURL(path)
        }
        
        // Retrieve the schema (e.g. "file://") and see whether the path type is supported.
        guard let url = URL(string: string),
              let schemeString = url.scheme,
              let scheme = SupportedScheme(rawValue: schemeString) else {
                throw Account.Error.invalidURL(string)
        }
        
        // Check that the url is bigger than just the scheme.
        let substring = string.dropFirst("\(scheme.rawValue)://".count)
        guard let first = substring.first else {
            throw Account.Error.invalidURL(string)
        }
        
        // If the scheme is a web URL or a local path pointing to the root folder (i.e. "/"), return the URL without further modifications.
        guard case .file = scheme, first != "/" else {
            return url
        }
        
        let resourcesURL = try bundleResourceURL()
        return resourcesURL.appendingPathComponent(String(substring))
    }
    
    /// Returns the URL for the test bundle resource.
    private static func bundleResourceURL() throws -> URL {
        let bundle = Bundle(for: UselessClass.self)
        guard let url = bundle.resourceURL else { throw Account.Error.bundleResourcesNotFound }
        return url
    }
    
    /// Empty class exclusively used to figure out the test bundle URL.
    private final class UselessClass { }
}
