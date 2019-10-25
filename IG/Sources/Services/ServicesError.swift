extension IG.Services {
    /// Wrapper for errors generated in one of the IG services.
    public enum Error: Swift.Error, CustomDebugStringConvertible {
        /// Error produced by the HTTP API subservice.
        case api(error: IG.API.Error)
        /// Error produced by the Lightstreamer subservice.
        case streamer(error: IG.Streamer.Error)
        /// Error produced by the Database subservice.
        case database(error: IG.DB.Error)
        
        public var debugDescription: String {
            switch self {
            case .api(let error): return error.debugDescription
            case .streamer(let error): return error.debugDescription
            case .database(let error): return error.debugDescription
            }
        }
        
        /// Transform the given `IG.Error` conforming type into a `IG.Services.Error`.
        /// - warning: This function will crash if the error type is not one of the supported by `IG.Services.Error`
        public init<E>(error: E) where E:IG.Error {
            switch error {
            case let e as IG.API.Error: self = .api(error: e)
            case let e as IG.Streamer.Error: self = .streamer(error: e)
            case let e as IG.DB.Error: self = .database(error: e)
            default: fatalError()
            }
        }
        
        /// A message accompaigning the error explaining what happened.
        var message: String {
            switch self {
            case .api(let error): return error.message
            case .streamer(let error): return error.message
            case .database(let error): return error.message
            }
        }
        /// Possible solutions for the problem.
        var suggestion: String {
            switch self {
            case .api(let error): return error.suggestion
            case .streamer(let error): return error.suggestion
            case .database(let error): return error.suggestion
            }
        }
        /// Store values/objects that gives context to the hosting error.
        var context: [IG.Error.Item] {
            switch self {
            case .api(let error): return error.context
            case .streamer(let error): return error.context
            case .database(let error): return error.context
            }
        }
    }
}
