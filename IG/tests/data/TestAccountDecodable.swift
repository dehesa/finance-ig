@testable import IG
import Foundation

extension Test.Account: Decodable {
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _CodingKeys.self)
        let identifier = try container.decode(IG.Account.Identifier.self, forKey: .accountId)
        let api = try container.decode(Self.APIData.self, forKey: .api)
        let streamer = try container.decodeIfPresent(Self.StreamerData.self, forKey: .streamer)
        let database = try container.decodeIfPresent(Self.DatabaseData.self, forKey: .database)
        self.init(identifier: identifier, api: api, streamer: streamer, database: database)
    }

    private enum _CodingKeys: String, CodingKey {
        case accountId, api, streamer, database
    }

    /// Loads the test account data from a file path specified as environment variable.
    /// - parameter environmentKey: Build variable key, which value gives the location of the account JSON file.
    /// - returns: Representation of the account file.
    convenience init(environmentKey: String) {
        let accountPath = ProcessInfo.processInfo.environment[environmentKey] ?! fatalError(Error.environmentVariableNotFound(key: environmentKey).debugDescription)

        let accountFileURL: URL
        do {
            accountFileURL = try Self._parse(path: accountPath)
        } catch let error { fatalError((error as! Test.Account.Error).debugDescription) }

        let data: Data
        do {
            data = try Data(contentsOf: accountFileURL)
        } catch let error { fatalError(Error.dataLoadFailed(url: accountFileURL, underlyingError: error).debugDescription) }

        do {
            let result = try JSONDecoder().decode(Self.self, from: data)
            self.init(identifier: result.identifier, api: result.api, streamer: result.streamer, database: result.database)
        } catch let error { fatalError(Error.accountParsingFailed(url: accountFileURL, underlyingError: error).debugDescription) }
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
    fileprivate static func _parse(path: String) throws -> URL {
        // Retrieve the schema (e.g. "file://") and see whether the path type is supported.
        guard let url = URL(string: path), let schemeString = url.scheme,
              let scheme = SupportedScheme(rawValue: schemeString) else {
            throw Self.Error.invalidURL(path)
        }
        
        // Check that the url is bigger than just the scheme.
        let substring = path.dropFirst("\(scheme.rawValue)://".count)
        guard let first = substring.first else { throw Self.Error.invalidURL(path) }
        
        // If the scheme is a web URL or a local path pointing to the root folder (i.e. "/"), return the URL without further modifications.
        guard case .file = scheme, first != "/" else { return url }
        
        let resourcesURL = try _bundleResourceURL()
        return resourcesURL.appendingPathComponent(String(substring))
    }
    
    /// Returns the URL for the test bundle resource.
    private static func _bundleResourceURL() throws -> URL {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.resourceURL else { throw Self.Error.bundleResourcesNotFound() }
        return url
    }
}

// MARK: -

extension Test.Account.APIData: Decodable {
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _CodingKeys.self)
        let rootURL = try Test.Account._parse(path: try container.decode(String.self, forKey: .rootURL))
        let key = try container.decode(API.Key.self, forKey: .key)

        var user: API.User? = nil
        if container.contains(.user) {
            let nested = try container.nestedContainer(keyedBy: _CodingKeys.NestedKeys.self, forKey: .user)
            let username = try nested.decode(API.User.Name.self, forKey: .name)
            let password = try nested.decode(String.self, forKey: .password)
            user = API.User(username, .init(stringLiteral: password))
        }

        var certificate: TokenCertificate? = nil
        if container.contains(.certificate) {
            let nested = try container.nestedContainer(keyedBy: _CodingKeys.NestedKeys.self, forKey: .certificate)
            let access = try nested.decode(String.self, forKey: .access)
            let security = try nested.decode(String.self, forKey: .security)
            certificate = (access, security)
        }

        var oauth: TokenOAuth? = nil
        if container.contains(.oauth) {
            let nested = try container.nestedContainer(keyedBy: _CodingKeys.NestedKeys.self, forKey: .oauth)
            let access = try nested.decode(String.self, forKey: .access)
            let refresh = try nested.decode(String.self, forKey: .refresh)
            let scope = try nested.decode(String.self, forKey: .scope)
            let type = try nested.decode(String.self, forKey: .type)
            oauth = (access, refresh, scope, type)
        }

        self.init(url: rootURL, key: key, user: user, certificate: certificate, oauth: oauth)
    }

    private enum _CodingKeys: String, CodingKey {
        case rootURL = "url", key, user, certificate, oauth

        enum NestedKeys: String, CodingKey {
            case name, password, access, security, refresh, scope, type
        }
    }
}

// MARK: -

extension Test.Account.StreamerData: Decodable {
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _CodingKeys.self)
        let rootURL = try Test.Account._parse(path: try container.decode(String.self, forKey: .rootURL))
        let identifier = try container.decode(IG.Account.Identifier.self, forKey: .identifier)

        var password: String? = nil
        if container.contains(.password) {
            if let pass = try? container.decode(String.self, forKey: .password) {
                password = pass
            } else {
                let nestedContainer = try container.nestedContainer(keyedBy: _CodingKeys.NestedKeys.self, forKey: .password)
                let access = try nestedContainer.decode(String.self, forKey: .access)
                let security = try nestedContainer.decode(String.self, forKey: .security)
                password = try Streamer.Credentials.password(fromCST: access, security: security)
                    ?> DecodingError.dataCorrupted(.init(codingPath: nestedContainer.codingPath, debugDescription: "The streamer password couldnt' be formed"))
            }
        }

        self.init(url: rootURL, identifier: identifier, password: password)
    }

    private enum _CodingKeys: String, CodingKey {
        case rootURL = "url", identifier, password

        enum NestedKeys: String, CodingKey {
            case access, security
        }
    }
}

// MARK: -

extension Test.Account.DatabaseData: Decodable {
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: _CodingKeys.self)

        var rootURL: URL? = nil
        if var url = try container.decodeIfPresent(URL.self, forKey: .rootURL) {
            guard url.isFileURL else { throw Test.Account.Error.invalidURL(url.path) }

            if let host = url.host, host == "~" {
                #if os(macOS)
                let absolutePath = url.absoluteString.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
                url = URL(string: absolutePath)!
                #else
                fatalError("Handle this case")
                #endif
            }
            rootURL = url.standardizedFileURL
        }
        
        self.init(url: rootURL)
    }

    private enum _CodingKeys: String, CodingKey {
        case rootURL = "url"
    }
}
