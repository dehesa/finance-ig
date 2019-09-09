import Foundation
@testable import IG

extension Test {
    /// Structure containing the loging information for the testing environment.
    struct Account: Decodable {
        /// The target account identifier.
        let identifier: IG.Account.Identifier
        /// List of variables required to connect to the API.
        let api: Self.APIData
        /// List of variables required to connect to the Streamer.
        let streamer: Self.StreamerData?
        /// List of variables required to open the underlying database file.
        let database: Self.DatabaseData?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.identifier = try container.decode(IG.Account.Identifier.self, forKey: .accountId)
            self.api = try container.decode(Self.APIData.self, forKey: .api)
            self.streamer = try container.decodeIfPresent(Self.StreamerData.self, forKey: .streamer)
            self.database = try container.decodeIfPresent(Self.DatabaseData.self, forKey: .database)
        }
        
        private enum CodingKeys: String, CodingKey {
            case accountId, api, streamer, database
        }
    }
}

// MARK: - API Data

extension Test.Account {
    /// Account test environment API information.
    struct APIData: Decodable {
        /// The root URL from where to call the endpoints.
        ///
        /// If this references a folder in the bundles file system, it shall be of type:
        /// ```
        /// file://API
        /// ```
        let rootURL: URL
        /// The API API key used to identify the developer.
        let key: IG.API.Key
        /// Credentials used on the API server
        let credentials: Self.Credentials
        
        /// Credentials for the API differentiating between User (name & password), CST, and OAuth.
        enum Credentials {
            case user(IG.API.User)
            case certificate(access: String, security: String)
            case oauth(access: String, refresh: String, scope: String, type: String)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.rootURL = try Test.Account.parse(path: try container.decode(String.self, forKey: .rootURL))
            guard let processedScheme = Test.Account.SupportedScheme(url: self.rootURL) else {
                throw DecodingError.dataCorruptedError(forKey: .rootURL, in: container, debugDescription: "The API scheme couldn't be inferred from the API root URL: \(self.rootURL)")
            }
            self.key = try container.decode(IG.API.Key.self, forKey: .key)
            
            if container.contains(.user) {
                let nested = try container.nestedContainer(keyedBy: Self.CodingKeys.NestedKeys.self, forKey: .user)
                let username = try nested.decode(IG.API.User.Name.self, forKey: .name)
                let password = try nested.decode(IG.API.User.Password.self, forKey: .password)
                self.credentials = .user(.init(username, password))
            } else if container.contains(.certificate) {
                let nested = try container.nestedContainer(keyedBy: Self.CodingKeys.NestedKeys.self, forKey: .certificate)
                let access = try nested.decode(String.self, forKey: .access)
                let security = try nested.decode(String.self, forKey: .security)
                self.credentials = .certificate(access: access, security: security)
            } else if container.contains(.oauth) {
                let nested = try container.nestedContainer(keyedBy: Self.CodingKeys.NestedKeys.self, forKey: .oauth)
                let access = try nested.decode(String.self, forKey: .access)
                let refresh = try nested.decode(String.self, forKey: .refresh)
                let scope = try nested.decode(String.self, forKey: .scope)
                let type = try nested.decode(String.self, forKey: .type)
                self.credentials = .oauth(access: access, refresh: refresh, scope: scope, type: type)
            } else if case .file = processedScheme {
                self.credentials = .user(.init("fake_user", "fake_password"))
            } else {
                let ctx = DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "There were no credentials on the test account file")
                throw DecodingError.keyNotFound(Self.CodingKeys.user, ctx)
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case rootURL = "url", key, user, certificate, oauth
            
            enum NestedKeys: String, CodingKey {
                case name, password, access, security, refresh, scope, type
            }
        }
    }
}

// MARK: - Streamer Data

extension Test.Account {
    /// Account test environment Streamer information.
    struct StreamerData: Decodable {
        /// Whether mocked files or actuall lightstreamer calls.
        let scheme: Test.Account.SupportedScheme
        /// The root URL from where to get the streaming messages.
        ///
        /// It can be one of the followings:
        /// - a forlder in the test bundle file system (e.g. `file://Streamer`).
        /// - a https URL (e.g. `https://demo-apd.marketdatasystems.com`).
        let rootURL: URL
        /// The Lightstreamer identifier and password.
        let credentials: (identifier: IG.Account.Identifier, password: String)?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.rootURL = try Test.Account.parse(path: try container.decode(String.self, forKey: .rootURL))
            guard let processedScheme = Test.Account.SupportedScheme(url: self.rootURL) else {
                throw DecodingError.dataCorruptedError(forKey: .rootURL, in: container, debugDescription: "The API scheme couldn't be inferred from the API root URL: \(self.rootURL)")
            }
            self.scheme = processedScheme
            
            if container.contains(.user) {
                let nested = try container.nestedContainer(keyedBy: Self.CodingKeys.NestedKeys.self, forKey: .user)
                let identifier = try nested.decode(IG.Account.Identifier.self, forKey: .identifier)
                guard nested.contains(.password) else {
                    let ctx = DecodingError.Context(codingPath: nested.codingPath, debugDescription: "The password key was not found")
                    throw DecodingError.keyNotFound(Self.CodingKeys.NestedKeys.password, ctx)
                }
                
                if let password = try? nested.decode(String.self, forKey: .password) {
                    self.credentials = (identifier, password)
                } else {
                    let passwordContainer = try nested.nestedContainer(keyedBy: Self.CodingKeys.NestedKeys.self, forKey: .password)
                    let access = try passwordContainer.decode(String.self, forKey: .access)
                    let security = try passwordContainer.decode(String.self, forKey: .security)
                    let password = try IG.Streamer.Credentials.password(fromCST: access, security: security)
                        ?! DecodingError.dataCorrupted(.init(codingPath: passwordContainer.codingPath, debugDescription: "The streamer password couldnt' be formed"))
                    self.credentials = (identifier, password)
                }
            } else if case .file = self.scheme {
                self.credentials = ("fake_identifier", "fake_password")
            }else {
                self.credentials = nil
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case rootURL = "url", user
            
            enum NestedKeys: String, CodingKey {
                case identifier, password, access, security
            }
        }
    }
}

// MARK: - Database Data

extension Test.Account {
    /// Account test environment Database information.
    struct DatabaseData: Decodable {
        /// The file URL where the database file is located.
        ///
        /// If `nil` an "in memory" database will be opened.
        let rootURL: URL?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            
            if var url = try container.decodeIfPresent(URL.self, forKey: .rootURL) {
                guard url.isFileURL else { throw Test.Account.Error.invalidURL(url.path) }
                
                if let host = url.host, host == "~" {
                    let absolutePath = url.absoluteString.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
                    url = URL(string: absolutePath)!
                }
                self.rootURL = url.standardizedFileURL
            } else {
                self.rootURL = nil
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case rootURL = "url"
        }
    }
}

// MARK: - Supporting Entities

extension Test.Account {
    /// Supported URL schemes for the rootURL
    enum SupportedScheme: String {
        case file
        case https
        
        init?(url: URL) {
            guard let urlScheme = url.scheme,
                  let result = Self.init(rawValue: urlScheme) else { return nil }
            self = result
        }
    }
}

// MARK: Interface

extension Test.Account {
    /// Load data to use as testing account/environment.
    /// - parameter environmentKey: Build variable key, which value gives the location of the account swift file.
    /// - returns: Representation of the account file.
    static func make(from environmentKey: String) -> Self {
        guard let accountPath = ProcessInfo.processInfo.environment[environmentKey] else {
            fatalError(Error.environmentVariableNotFound(key: environmentKey).debugDescription)
        }
        
        let accountFileURL: URL
        do {
            accountFileURL = try Self.parse(path: accountPath)
        } catch let error {
            fatalError((error as! Self.Error).debugDescription)
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: accountFileURL)
        } catch let error {
            fatalError(Error.dataLoadFailed(url: accountFileURL, underlyingError: error).debugDescription)
        }
        
        do {
            return try JSONDecoder().decode(Self.self, from: data)
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
    fileprivate static func parse(path: String) throws -> URL {
        // Retrieve the schema (e.g. "file://") and see whether the path type is supported.
        guard let url = URL(string: path),
              let schemeString = url.scheme,
              let scheme = SupportedScheme(rawValue: schemeString) else {
                throw Self.Error.invalidURL(path)
        }
        
        // Check that the url is bigger than just the scheme.
        let substring = path.dropFirst("\(scheme.rawValue)://".count)
        guard let first = substring.first else {
            throw Self.Error.invalidURL(path)
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
        guard let url = bundle.resourceURL else { throw Self.Error.bundleResourcesNotFound() }
        return url
    }
    
    /// Empty class exclusively used to figure out the test bundle URL.
    private final class UselessClass {}
}
