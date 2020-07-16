extension Services {
    /// Wrapper for errors generated in one of the IG services.
    public enum Error: Swift.Error {
        /// Error produced by the HTTP API subservice.
        case api(error: API.Error)
        /// Error produced by the Lightstreamer subservice.
        case streamer(error: Streamer.Error)
        /// Error produced by the Database subservice.
        case database(error: Database.Error)
        /// Error produced by the framework user.
        case user(String, suggestion: String, context: [IG.Error.Item] = [])
        
        /// Transform the given `IG.Error` conforming type into a `Services.Error`.
        /// - warning: This function will crash if the error type is not one of the supported by `Services.Error`
        public init<E>(error: E) where E:IG.Error {
            switch error {
            case let e as API.Error: self = .api(error: e)
            case let e as Streamer.Error: self = .streamer(error: e)
            case let e as Database.Error: self = .database(error: e)
            default: fatalError()
            }
        }
        
        /// A message accompaigning the error explaining what happened.
        public var message: String {
            switch self {
            case .api(let error): return error.message
            case .streamer(let error): return error.message
            case .database(let error): return error.message
            case .user(let message, _, _): return message
            }
        }
        /// Possible solutions for the problem.
        public var suggestion: String {
            switch self {
            case .api(let error): return error.suggestion
            case .streamer(let error): return error.suggestion
            case .database(let error): return error.suggestion
            case .user(_, let suggestion, _): return suggestion
            }
        }
        /// Store values/objects that gives context to the hosting error.
        public var context: [IG.Error.Item] {
            switch self {
            case .api(let error): return error.context
            case .streamer(let error): return error.context
            case .database(let error): return error.context
            case .user(_, _, let context): return context
            }
        }
    }
}
