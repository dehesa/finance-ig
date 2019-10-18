import IG
import Foundation

enum Arguments {
    /// A flag is a `CommandLine` argument with one or two dashes.
    typealias Flag = (short: String, verbose: String)
    /// Optional configuration file detailing some arguments.
    private static let configFile: Flag = ("-c", "--configuration")
    /// Optional argument specifying the API root URL.
    private static let server: Flag = ("-s", "--server")
    /// Optional argument specifying the file URL where the SQLite is (or will be) located.
    private static let database: Flag = ("-d", "--database")
    /// Required API key used to identify this application on the IG platform.
    private static let apiKey: Flag = ("-k", "--apikey")
    /// Required user name to reach IG's platform.
    private static let username: Flag = ("-u", "--username")
    /// Required user password to reach IG's platform.
    private static let password: Flag = ("-p", "--password")
    
    /// Parses the given command-line arguments innto Application configurations.
    /// - parameter path: The command-line app binary path. It is always the first element in the `CommandLine` array.
    /// - parameter arguments: Any other command-line argument.
    /// - returns: All configurations for the given binary.
    /// - throws: `Arguments.Error` exclusively
    static func parse(path: String, arguments: [String]) throws -> Configuration {
        let runURL = URL(fileURLWithPath: path).deletingLastPathComponent()
        let file = try Self.extractConfigFile(from: arguments)
        
        let serverURL: URL
        if let explicitURL = try Self.extractServerURL(from: arguments) {
            serverURL = explicitURL
        } else if let configDefinedPath = file?.server {
            serverURL = try Self.validateURL(path: configDefinedPath)
        } else {
            serverURL = IG.API.rootURL
        }
        
        let databaseURL: URL?
        if let explicitURL = try Self.extractDatabaseURL(from: arguments) {
            databaseURL = explicitURL
        } else if let configDefinedPath = file?.database {
            databaseURL = FileManager.default.parse(filePath: configDefinedPath)
        } else {
            databaseURL = nil
        }
        
        let apiKey: IG.API.Key
        if let explicitAPIKey = try Self.extractAPIKey(from: arguments) {
            apiKey = explicitAPIKey
        } else if let configDefinedKey = file?.apikey {
            apiKey = configDefinedKey
        } else {
            throw Self.Error.flagNotFound(Self.apiKey)
        }
        
        let username: IG.API.User.Name
        if let explicitUsername = try Self.extractUserName(from: arguments) {
            username = explicitUsername
        } else if let configDefinedName = file?.username {
            guard let name = IG.API.User.Name(rawValue: configDefinedName) else {
                throw Self.Error.invalidValue(description: #"The given username \#(configDefinedName) is invalid"#)
            }
            username = name
        } else {
            throw Self.Error.flagNotFound(Self.username)
        }
        
        let password: IG.API.User.Password
        if let explicitPassword = try Self.extractUserPassword(from: arguments) {
            password = explicitPassword
        } else if let configDefinedPassword = file?.password {
            guard let pass = IG.API.User.Password(rawValue: configDefinedPassword) else {
                throw Self.Error.invalidValue(description: "The given password is invalid")
            }
            password = pass
        } else {
            throw Self.Error.flagNotFound(Self.password)
        }
        
        return Configuration(runURL: runURL, serverURL: serverURL, databaseURL: databaseURL, apiKey: apiKey, user: .init(username, password))
    }
}

extension Arguments {
    /// List of errors thrown by the `CommandLine` arguments parsing.
    enum Error: Swift.Error, CustomStringConvertible {
        /// The given flag has been given more than once (check that you are not writing the short and verbose version of the flags).
        case duplicateArguments([String])
        /// The specified flag is required, but it wasn't found.
        case flagNotFound(Flag)
        /// An invalid value was detected when parsing `CommandLine` arguments.
        case invalidValue(description: String)
        /// The configuration file provided couldn't be decoded.
        case invalidConfigFile(underlyingError: Swift.Error)
        
        var description: String {
            switch self {
            case .duplicateArguments(let args):
                return "The arguments \(args.map { #""\#($0)""# }.joined(separator: ", ")) cannot appear together. Choose one of them."
            case .flagNotFound(let flag):
                return #"The flag "\#(flag.short)" or "\#(flag.verbose)" is required"#
            case .invalidValue(let description):
                return description
            case .invalidConfigFile(let underlyingError):
                return "The configuration file specifying the running flags couldn't be decoded. The underlying error states:\n\(underlyingError)"
            }
        }
    }
}

extension Arguments {
    /// The configuration file used so a user doesn't have to be inputing all flags all the time.
    ///
    /// The JSON fields have the same names as the argument flags.
    struct ConfigFile: Decodable {
        let server: String?
        let database: String?
        let apikey: IG.API.Key?
        let username: String?
        let password: String?
    }
    
    /// Returns the configuration file if the flag is defined and the path is correct.
    /// - parameter arguments: `CommandLine` arguments.
    /// - throws: `Arguments.Error` exclusively.
    private static func extractConfigFile(from arguments: [String]) throws -> ConfigFile? {
        guard let flag = try Self.extract(flag: Self.configFile, from: arguments) else { return nil }
        let path = try Self.extractValue(nextTo: flag, from: arguments)
        let fileURL = FileManager.default.parse(filePath: path)
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(Self.ConfigFile.self, from: data)
        } catch let error {
            throw Self.Error.invalidConfigFile(underlyingError: error)
        }
    }
    
    /// Returns the file URL to the configuration file if the flag is defined.
    /// - parameter arguments: `CommandLine` arguments.
    /// - throws: `Arguments.Error` exclusively.
    private static func extractConfigFileURL(from arguments: [String]) throws -> URL? {
        guard let flag = try Self.extract(flag: Self.configFile, from: arguments) else { return nil }
        let path = try Self.extractValue(nextTo: flag, from: arguments)
        return FileManager.default.parse(filePath: path)
    }
}

extension Arguments {
    /// Returns the server URL from the given arguments or `nil` if not defined.
    /// - parameter arguments: `CommandLine` arguments.
    /// - throws: `Arguments.Error` exclusively.
    private static func extractServerURL(from arguments: [String]) throws -> URL? {
        guard let flag = try Self.extract(flag: Self.server, from: arguments) else { return nil }
        
        let path = try Self.extractValue(nextTo: flag, from: arguments)
        return try Self.validateURL(path: path)
    }
    
    /// Returns the database file URL or `nil` if it is not defined.
    /// - parameter arguments: `CommandLine` arguments.
    /// - throws: `Arguments.Error` exclusively.
    private static func extractDatabaseURL(from arguments: [String]) throws -> URL? {
        guard let flag = try Self.extract(flag: Self.database, from: arguments) else { return nil }
        
        let path = try Self.extractValue(nextTo: flag, from: arguments)
        return FileManager.default.parse(filePath: path)
    }
    
    /// Returns the API key encoded as an argument or `nil` if it is not defined.
    /// - parameter arguments: `CommandLine` arguments.
    /// - throws: `Arguments.Error` exclusively.
    private static func extractAPIKey(from arguments: [String]) throws -> IG.API.Key? {
        guard let flag = try Self.extract(flag: Self.apiKey, from: arguments) else { return nil }
        
        let value = try Self.extractValue(nextTo: flag, from: arguments)
        guard let key = IG.API.Key(rawValue: value) else {
            throw Self.Error.invalidValue(description: #"The API key provided "\#(value)" is invalid"#)
        }
        return key
    }
    
    /// Returns the user name from the `CommandLine` arguments or `nil` if it is not defined.
    /// - parameter arguments: `CommandLine` arguments.
    /// - throws: `Arguments.Error` exclusively.
    private static func extractUserName(from arguments: [String]) throws -> IG.API.User.Name? {
        guard let flag = try Self.extract(flag: Self.username, from: arguments) else { return nil }
        
        let value = try Self.extractValue(nextTo: flag, from: arguments)
        guard let name = IG.API.User.Name(rawValue: value) else {
            throw Self.Error.invalidValue(description: "The user name input is invalid. Please check the values after \(flag.flag).")
        }
        return name
    }
    
    /// Returns the user name from the `CommandLine` arguments or `nil` if it is not defined.
    /// - parameter arguments: `CommandLine` arguments.
    /// - throws: `Arguments.Error` exclusively.
    private static func extractUserPassword(from arguments: [String]) throws -> IG.API.User.Password? {
        guard let flag = try Self.extract(flag: Self.password, from: arguments) else { return nil }
        
        let value = try Self.extractValue(nextTo: flag, from: arguments)
        guard let password = IG.API.User.Password(rawValue: value) else {
            throw Self.Error.invalidValue(description: "The user password input is invalid. Please check the values after \(flag.flag).")
        }
        return password
    }
}

extension Arguments {
    /// Returns an array with the given flag values and its positions in the `CommandLine` arguments array.
    ///
    /// The returned array can be empty (if no flags are defined), or filled with one or more flags (if they are duplicated).
    /// - parameter flag: The argument's flag being targeted.
    /// - parameter arguments: `CommandLine` arguments.
    /// - throws: `Arguments.Error` exclusively.
    private static func extract(flag: Flag, from arguments: [String]) throws -> (flag: String, index: Int)? {
        let flags = arguments.enumerated()
            .filter { $0.element == flag.short || $0.element == flag.verbose }
            .map { ($0.element, $0.offset) }
        
        switch flags.count {
        case 0: return nil
        case 1: return flags[0]
        default: throw Self.Error.duplicateArguments(flags.map { $0.0 })
        }
    }
    /// Returns the value next to the given offset.
    /// - parameter target: The flag from which the next value will be extracted.
    /// - parameter arguments: `CommandLine` arguments.
    /// - throws: `Arguments.Error` exclusively.
    private static func extractValue(nextTo target: (flag: String, index: Int), from arguments: [String]) throws -> String {
        let index = target.index + 1
        guard index < arguments.count else { throw Self.Error.invalidValue(description: "There was no value after the \(target.flag) flag") }
        
        let value = arguments[index]
        guard !value.isEmpty else { throw Self.Error.invalidValue(description: "The value after the \(target.flag) flag is empty") }
        return value
    }
    
    /// Checks the provided path to see if it is a proper HTTPS URL.
    private static func validateURL(path: String) throws -> URL {
        guard let url = URL(string: path),
              let scheme = url.scheme else {
                throw Self.Error.invalidValue(description: #"The URL "\#(path)" provided is invalid"#)
        }
        guard scheme.lowercased() == "https" else {
            throw Self.Error.invalidValue(description: #"The URL "\#(path)" provided must be secure (i.e. "https")"#)
        }
        
        return url
    }
}
