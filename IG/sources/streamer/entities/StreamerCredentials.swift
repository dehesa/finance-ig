extension Streamer {
    /// Data needed to access the Streaming service.
    public struct Credentials: Equatable {
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
        public init(credentials: API.Credentials) throws {
            guard case .certificate(let access, let security) = credentials.token.value else {
                throw IG.Error(.streamer(.invalidRequest), "Invalid API credentials.", help: "Log in to the API with 'certificate' credentials.")
            }
            
            guard let password = Streamer.Credentials.password(fromCST: access, security: security) else {
                throw IG.Error(.streamer(.invalidRequest), "Invalid streamer password.", help: "There seems to be a problem with the 'certificate' password provided. If you input it manually, double check it. If not, contact the repository maintainer.")
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
