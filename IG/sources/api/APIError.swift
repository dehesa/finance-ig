import Foundation

extension API {
    /// Wraps any error generated by the API request/response system.
    ///
    /// When `underlyingError` is set, most of them will be coming from a `URLSession` or sent when encoding/decoding JSONs.
    public struct Error: IG.Error {
        public let type: Self.Kind
        public internal(set) var message: String
        public internal(set) var suggestion: String
        public internal(set) var underlyingError: Swift.Error?
        public internal(set) var context: [Self.Item] = []
        /// The URL request that generated the error.
        public internal(set) var request: URLRequest?
        /// The URL response generated when the error occurred.
        public internal(set) var response: HTTPURLResponse?
        /// The data received from the server.
        public internal(set) var responseData: Data?
        /// The server sends error codes when a request was invalid or on per-request basis.
        ///
        /// If the error contains a `responseData`, this data may be decoded into a server code message.
        public var serverCode: String? {
            guard let data = self.responseData,
                  let payload = try? JSONDecoder().decode(_Payload.self, from: data) else { return nil }
            return payload.code
        }
        
        /// Designated initializer, filling all required error fields.
        /// - parameter type: The error type.
        /// - parameter message: A brief explanation on what happened.
        /// - parameter suggestion: A helpful suggestion on how to avoid the error.
        /// - parameter request: The request that raised the error.
        /// - parameter response: The response that raised the error.
        /// - parameter data: The response data accompaigning the response.
        /// - parameter error: The underlying error that happened right before this error was created.
        fileprivate init(_ type: Self.Kind, _ message: String, suggestion: String, request: URLRequest? = nil, response: HTTPURLResponse? = nil, data: Data? = nil, underlying error: Swift.Error? = nil) {
            self.type = type
            self.message = message
            self.suggestion = suggestion
            self.underlyingError = error
            self.request = request
            self.response = response
            self.responseData = data
        }
        
        /// Wrap the argument error in a `API` error.
        /// - parameter error: Swift error to be wrapped.
        internal static func transform(_ error: Swift.Error) -> Self {
            switch error {
            case let e as Self: return e
            case let e: return .unknown(message: "An unknown error has occurred", underlyingError: e, suggestion: .reviewError)
            }
        }
    }
}

extension API.Error {
    /// The type of API error raised.
    public enum Kind: CaseIterable {
        /// The API/URLSession experied before the endpoint call could finish.
        case sessionExpired
        /// The request parameters given are invalid.
        case invalidRequest
        /// A URL request was executed, but an error was returned by low-level layers.
        case callFailed
        /// The received response was invalid.
        case invalidResponse
        /// Unknown (not recognized) error.
        case unknown
    }
    
    /// A factory function for `.sessionExpired` API errors.
    /// - parameter message: A brief explanation on what happened.
    /// - parameter suggestion: A helpful suggestion on how to avoid the error.
    internal static func sessionExpired(message: Self.Message = .sessionExpired, suggestion: Self.Suggestion = .keepSession) -> Self {
        self.init(.sessionExpired, message.rawValue, suggestion: suggestion.rawValue)
    }
    
    /// A factory function for `.invalidRequest` API errors.
    /// - parameter message: A brief explanation on what happened.
    /// - parameter request: The request that raised the error.
    /// - parameter error: The underlying error that happened right before this error was created.
    /// - parameter suggestion: A helpful suggestion on how to avoid the error.
    internal static func invalidRequest(_ message: Self.Message, request: URLRequest? = nil, underlying error: Swift.Error? = nil, suggestion: Self.Suggestion) -> Self {
        self.init(.invalidRequest, message.rawValue, suggestion: suggestion.rawValue, request: request, underlying: error)
    }
    
    /// A factory function for `.callFailed` API errors.
    /// - parameter message: A brief explanation on what happened.
    /// - parameter request: The request that raised the error.
    /// - parameter error: The underlying error that happened right before this error was created.
    /// - parameter suggestion: A helpful suggestion on how to avoid the error.
    internal static func callFailed(message: Self.Message, request: URLRequest, response: HTTPURLResponse?, data: Data?, underlying error: Swift.Error?, suggestion: Self.Suggestion) -> Self {
        self.init(.callFailed, message.rawValue, suggestion: suggestion.rawValue, request: request, response: response, data: data, underlying: error)
    }
    
    /// A factory function for `.invalidResponse` API errors.
    /// - parameter message: A brief explanation on what happened.
    /// - parameter request: The request that raised the error. 
    /// - parameter error: The underlying error that happened right before this error was created.
    /// - parameter suggestion: A helpful suggestion on how to avoid the error.
    internal static func invalidResponse(message: Self.Message, request: URLRequest, response: HTTPURLResponse, data: Data? = nil, underlying error: Swift.Error? = nil, suggestion: Self.Suggestion) -> Self {
        self.init(.invalidResponse, message.rawValue, suggestion: suggestion.rawValue, request: request, response: response, data: data, underlying: error)
    }
    
    /// A factory function for `.unknown` API errors.
    /// - parameter message: A brief explanation on what happened.
    /// - parameter error: The underlying error that happened right before this error was created.
    /// - parameter suggestion: A helpful suggestion on how to avoid the error.
    internal static func unknown(message: Self.Message, underlyingError error: Swift.Error?, suggestion: Self.Suggestion) -> Self {
        self.init(.unknown, message.rawValue, suggestion: suggestion.rawValue, request: nil, response: nil, data: nil, underlying: error)
    }
}

extension API.Error {
    /// Namespace for messages reused over the framework.
    internal struct Message: IG.ErrorNameSpace {
        let rawValue: String; init(_ trustedValue: String) { self.rawValue = trustedValue }
        
        static var sessionExpired: Self { "The API instance was not found" }
        static var noCredentials: Self  { "No credentials were found on the API instance" }
        static var invalidTrailingStop: Self { "Invalid trailing stop setting" }
    }
    
    /// Namespace for suggestions reused over the framework.
    internal struct Suggestion: IG.ErrorNameSpace {
        let rawValue: String; init(_ trustedValue: String) { self.rawValue = trustedValue }
        
        static var logIn: Self       { "Log in before calling this request" }
        static var keepSession: Self { "API functionality is asynchronous; keep around the API instance while a response hasn't been received" }
        static var readDocs: Self    { "Read the request documentation and be sure to follow all requirements" }
        static var reviewError: Self { "Review the returned error and try to fix the problem" }
        static var fileBug: Self     { "A unexpected error was encountered. Please contact the repository maintainer and attach this debug print" }
        static var validLimit: Self  { "If the limit mode '.distance()' is chosen, input a positive number greater than zero. If the limit mode '.level()' is chosen, be sure the limit is above the reference level for 'BUY' deals and below it for 'SELL' deals" }
        static var validStop: Self   { "If the stop mode '.distance()' is chose, input a positive number greater than zero. If the stop mode '.level()' is chosen, be sure the stop is below the reference level for 'BUY' deals and above it for 'SELL' deals" }
    }

    /// A typical server error payload.
    private struct _Payload: Decodable {
        /// The server error code.
        let code: String

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: _CodingKeys.self)
            self.code = try container.decode(String.self, forKey: .code)
            
            let keys = container.allKeys
            guard keys.count == 1 else {
                let ctx = DecodingError.Context(codingPath: container.codingPath, debugDescription: "The server error payload (JSON) was expected to have only one key, but it has \(keys.count): '\(keys.map { $0.rawValue }.joined(separator: ", "))'")
                throw DecodingError.typeMismatch(Self.self, ctx)
            }
        }

        private enum _CodingKeys: String, CodingKey {
            case code = "errorCode"
        }
    }
}
