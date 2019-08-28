import Foundation

extension API {
    /// List of errors that can be generated through the API.
    public struct Error: IG.Error {
        public let type: Self.Kind
        public internal(set) var message: String
        public internal(set) var suggestion: String
        public internal(set) var underlyingError: Swift.Error?
        public internal(set) var context: [(title: String, value: Any)] = []
        /// The URL request that generated the error.
        public internal(set) var request: URLRequest?
        /// The URL response generated when the error occurred.
        public internal(set) var response: HTTPURLResponse?
        /// The data received from the server.
        public internal(set) var responseData: Data?
        
        /// Designated initializer, filling all required error fields.
        /// - parameter type: The error type.
        /// - parameter message: A brief explanation on what happened.
        /// - parameter suggestion: A helpful suggestion on how to avoid the error.
        /// - parameter request: The request that raised the error.
        /// - parameter response: The response that raised the error.
        /// - parameter data: The response data accompaigning the response.
        /// - parameter error: The underlying error that happened right before this error was created.
        internal init(_ type: Self.Kind, _ message: String, suggestion: String, request: URLRequest? = nil, response: HTTPURLResponse? = nil, data: Data? = nil, underlying error: Swift.Error? = nil) {
            self.type = type
            self.message = message
            self.suggestion = suggestion
            self.underlyingError = error
            self.request = request
            self.response = response
            self.responseData = data
        }
        
        /// A factory function for `.sessionExpired` API errors.
        /// - parameter message: A brief explanation on what happened.
        /// - parameter suggestion: A helpful suggestion on how to avoid the error.
        internal static func sessionExpired(message: String = Self.Message.sessionExpired, suggestion: String = Self.Suggestion.keepSession) -> Self {
            self.init(.sessionExpired, message, suggestion: suggestion)
        }
        
        /// A factory function for `.invalidRequest` API errors.
        /// - parameter message: A brief explanation on what happened.
        /// - parameter suggestion: A helpful suggestion on how to avoid the error.
        internal static func invalidRequest(_ message: String, request: URLRequest? = nil, underlying error: Swift.Error? = nil, suggestion: String) -> Self {
            self.init(.invalidRequest, message, suggestion: suggestion, request: request, underlying: error)
        }

        /// A factory function for `.callFailed` API errors.
        /// - parameter message: A brief explanation on what happened.
        /// - parameter suggestion: A helpful suggestion on how to avoid the error.
        internal static func callFailed(message: String, request: URLRequest, response: HTTPURLResponse?, data: Data?, underlying error: Swift.Error?, suggestion: String) -> Self {
            self.init(.callFailed, message, suggestion: suggestion, request: request, response: response, data: data, underlying: error)
        }
        
        /// A factory function for `.invalidResponse` API errors.
        /// - parameter message: A brief explanation on what happened.
        /// - parameter suggestion: A helpful suggestion on how to avoid the error.
        internal static func invalidResponse(message: String, request: URLRequest, response: HTTPURLResponse, data: Data? = nil, underlying error: Swift.Error? = nil, suggestion: String) -> Self {
            self.init(.invalidResponse, message, suggestion: suggestion, request: request, response: response, data: data, underlying: error)
        }
        
        /// The server sends error codes when a request was invalid or on per-request basis.
        ///
        /// If the error contains a `responseData`, this data may be decoded into a server code message.
        var serverCode: String? {
            guard let data = self.responseData,
                  let payload = try? JSONDecoder().decode(Self.Payload.self, from: data) else { return nil }
            return payload.code
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
    }
    
    /// Namespace for messages reused over the framework.
    internal enum Message {
        static var sessionExpired: String { "The API instance was not found." }
        static var noCredentials: String { "No credentials were found on the API instance." }
        static var invalidTrailingStop: String { "Invalid trailing stop setting" }
    }
    
    /// Namespace for suggestions reused over the framework.
    internal enum Suggestion {
        static var keepSession: String { "API functionality is asynchronous; keep around the API instance while a response hasn't been received." }
        static var readDocumentation: String { "Read the request documentation and be sure to follow all requirements." }
        static var logIn: String { "Log in before calling this request." }
        static var bug: String { "A unexpected error was encountered. Please contact the repository maintainer and attach this debug print." }
        static var reviewError: String { "Review the returned error and try to fix the problem." }
        static var validLimit: String { #"If the limit mode ".distance()" is chosen, input a positive number greater than zero. If the limit mode ".level()" is chosen, be sure the limit is above the reference level for "BUY" deals and below it for "SELL" deals."# }
        static var validStop: String { #"If the stop mode ".distance()" is chose, input a positive number greater than zero. If the stop mode ".level()" is chosen, be sure the stop is below the reference level for "BUY" deals and above it for "SELL" deals."# }
    }

    /// A typical server error payload.
    private struct Payload: Decodable {
        /// The server error code.
        let code: String

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.code = try container.decode(String.self, forKey: .code)
            
            let keys = container.allKeys
            guard keys.count == 1 else {
                let ctx = DecodingError.Context(codingPath: container.codingPath, debugDescription: "The server error payload (JSON) was expected to have only one key, but it has \(keys.count): \"\(keys.map { $0.rawValue }.joined(separator: ", "))\"")
                throw DecodingError.typeMismatch(Self.self, ctx)
            }
        }

        enum CodingKeys: String, CodingKey {
            case code = "errorCode"
        }
    }
}

extension API.Error: ErrorPrintable {
    var printableDomain: String {
        return "API Error"
    }
    
    var printableType: String {
        switch self.type {
        case .sessionExpired: return "Session expired"
        case .invalidRequest: return "Invalid request"
        case .callFailed: return "HTTP call failed"
        case .invalidResponse: return "Invalid HTTP response"
        }
    }
    
    public var debugDescription: String {
        var result = self.printableHeader
        
        if let request = self.request {
            result.append("\(Self.prefix)URL Request: ")
            
            if let method = request.httpMethod {
                result.append("\(method) ")
            }
            
            if let url = request.url {
                result.append("\(url), ")
            }
            
            if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
                result.append("\(Self.prefix)\tHeaders: [")
                result.append(headers.map { "\($0): \($1)" }.joined(separator: ", "))
                result.append("]")
            }
        }
        
        if let response = self.response {
            result.append("\(Self.prefix)Response code: \(response.statusCode)")
            
            if let headers = response.allHeaderFields as? [String:String], !headers.isEmpty {
                result.append("\(Self.prefix)\tHeaders: [")
                result.append(headers.map { "\($0): \($1)" }.joined(separator: ", "))
                result.append("]")
            }
        }
        
        if let serverCode = self.serverCode {
            result.append("\(Self.prefix)Server code: \(serverCode)")
        } else if let data = self.responseData {
            let representation = String(decoding: data, as: UTF8.self)
            result.append("\(Self.prefix)Response data: \(representation)")
        }
        
        if let contextString = self.printableContext {
            result.append(contextString)
        }
        
        if let underlyingString = self.printableUnderlyingError {
            result.append(underlyingString)
        }
        
        result.append("\n")
        return result
    }
}
