extension IG.Services {
    /// Wrapper for errors generated in one of the IG services.
    public enum Error: Swift.Error {
        /// Error produced by the HTTP API subservice.
        case api(error: IG.API.Error)
        /// Error produced by the Lightstreamer subservice.
        case streamer(error: IG.Streamer.Error)
        /// Error produced by the Database subservice.
        case database(error: IG.Database.Error)
        /// Error produced by the framework user.
        case user(String, suggestion: String, context: [IG.Error.Item] = [])
        
        /// Transform the given `IG.Error` conforming type into a `IG.Services.Error`.
        /// - warning: This function will crash if the error type is not one of the supported by `IG.Services.Error`
        public init<E>(error: E) where E:IG.Error {
            switch error {
            case let e as IG.API.Error: self = .api(error: e)
            case let e as IG.Streamer.Error: self = .streamer(error: e)
            case let e as IG.Database.Error: self = .database(error: e)
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

extension IG.Services.Error: IG.ErrorPrintable {
    static var printableDomain: String { "\(IG.Services.printableDomain).\(Self.self)" }
    
    var printableType: String {
        switch self {
        case .user: return "User defined"
        case .api, .streamer, .database: fatalError()
        }
    }
    
    func printableMultiline(level: Int) -> String {
        let levelPrefix    = Self.debugPrefix(level: level+1)
        let sublevelPrefix = Self.debugPrefix(level: level+2)
        
        var result = "\(Self.printableDomain) (\(self.printableType))"
        result.append("\(levelPrefix)Error message: \(self.message)")
        result.append("\(levelPrefix)Suggestions: \(self.suggestion)")
        
        if !self.context.isEmpty {
            result.append("\(levelPrefix)Error context: \(IG.ErrorHelper.representation(of: self.context, itemPrefix: sublevelPrefix, maxCharacters: Self.maxCharsPerLine))")
        }
        
        return result
    }
    
    public var debugDescription: String {
        switch self {
        case .api(let error): return error.debugDescription
        case .streamer(let error): return error.debugDescription
        case .database(let error): return error.debugDescription
        case .user: break
        }
        
        var result = Self.debugPrefix(level: 0)
        result.append(self.printableMultiline(level: 0))
        result.append("\n")
        return result
    }
}
