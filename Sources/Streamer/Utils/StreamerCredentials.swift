import Foundation

extension Streamer {
    /// Data needed to access the Streaming service.
    public struct Credentials {
        /// Active IG account identifier.
        public let identifier: String
        /// Lightstreamer temporal password.
        public let password: String
        
        /// Initializer for hardcoded data.
        /// - parameter identifier: The account identifier.
        /// - parameter password: The lightstreamer password.
        public init(identifier: String, password: String) {
            self.identifier = identifier
            self.password = password
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

extension Streamer.Credentials: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        Streamer credentials {
            Identifier: \(self.identifier)
            Password:   \(self.password)
        }
        """
    }
}

extension API.Credentials {
    /// Convenience initializer to create the credentials for the Streamer.
    ///
    /// - throws: API.Error.invalidCredentials if the receiving credentials is not of certificate type.
    public func streamerCredentials() throws -> Streamer.Credentials {
        guard case .certificate(let access, let security) = self.token.value else {
            throw API.Error.invalidCredentials(self, message: "Streamer credentials initialization failed! The passed API credentials are not of \"certificate\" type.")
        }
        
        guard let password = Streamer.Credentials.password(fromCST: access, security: security) else {
            throw API.Error.invalidCredentials(self, message: "The Streamer password couldn't be formed with the given credentials.")
        }
        
        return Streamer.Credentials(identifier: self.accountId, password: password)
    }
}
