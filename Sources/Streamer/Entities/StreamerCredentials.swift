import Foundation

extension Streamer {
    /// Data needed to access the Streaming service.
    public struct Credentials {
        /// Active IG account identifier.
        public let identifier: IG.Account.Identifier
        /// Lightstreamer temporal password.
        public let password: String
        
        /// Initializer for hardcoded data.
        /// - parameter identifier: The account identifier.
        /// - parameter password: The lightstreamer password.
        public init(identifier: IG.Account.Identifier, password: String) {
            self.identifier = identifier
            self.password = password
        }
        
        /// Creates the `Streamer` credentials from the received `API` credentials.
        /// - parameter credentials: API secret with all the information to create the `Streamer` credentials.
        /// - throws: `Streamer.Error.invalidRequest`
        public init(credentials: IG.API.Credentials) throws {
            guard case .certificate(let access, let security) = credentials.token.value else {
                throw IG.Streamer.Error.invalidRequest("No Certificate credentials were found", suggestion: #"Set the API log in as "certificate" type"#)
            }
            
            guard let password = IG.Streamer.Credentials.password(fromCST: access, security: security) else {
                throw IG.Streamer.Error.invalidRequest("The Streamer password couldn't be formed with the given credentials", suggestion: #"There seems to be a problem with the "certificate" password provided. If you input it manually, double check it. If not, contact the repository maintainer"#)
            }
            
            self.init(identifier: credentials.account, password: password)
        }
        
        /// Encapsulates the creation of a Lightstreamer password.
        /// - parameter cst: The certificate string password.
        /// - parameter sec: The security header password.
        /// - returns: The joint cst + security password.
        internal static func password(fromCST cst: String?, security sec: String?) -> String? {
            var password = String()
            if let certificate = cst, !certificate.isEmpty {
                password = "CST-" + certificate
            }
            
            if let security = sec, !security.isEmpty {
                if !password.isEmpty {
                    password += "|"
                }
                password += "XST-" + security
            }
            
            return (password.isEmpty) ? nil : password
        }
    }
}

extension IG.Streamer.Credentials: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = IG.DebugDescription("Streamer Credentials")
        result.append("identifier", self.identifier)
        result.append("password", self.password)
        return result.generate()
    }
}
