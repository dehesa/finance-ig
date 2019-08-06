import Foundation

extension API {
    /// List of errors that can be generated through the API.
    public enum Error: Swift.Error {
        /// The API/URLSession experied before the endpoint call could finish.
        case sessionExpired
        /// There were no credentials or a problem was encountered when unpacking login credentials.
        case invalidCredentials(API.Credentials?, message: String)
        /// The request parameters given are invalid.
        case invalidRequest(underlyingError: Swift.Error?, message: String)
        /// The given request was executed, but the given error was returned by low-level layers, or the response couldn't be parsed.
        case callFailed(request: URLRequest, response: URLResponse?, underlyingError: Swift.Error?, message: String)
        /// The received response was invalid. In most cases `URLResponse` will be of type `HTTPURLResponse`.
        case invalidResponse(HTTPURLResponse, request: URLRequest, data: Data?, underlyingError: Swift.Error?, message: String)
    }
}

extension API.Error: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = ErrorPrint(domain: "API Error")
        
        switch self {
        case .sessionExpired:
            result.title = "Session expired."
            result.append(details: "The underlying URL session or the \(API.self) instance cannot be found. You can probably solve this problem by creating a strong reference to the \(API.self) instance.")
        case .invalidCredentials(let credentials, let message):
            result.title = "Invalid credentals."
            result.append(details: message)
            result.append(involved: credentials)
        case .invalidRequest(let error, let message):
            result.title = "Invalid request."
            result.append(details: message)
            result.append(underlyingError: error)
        case .callFailed(let request, let response, let error, let message):
            result.title = "Call failed"
            result.append(details: message)
            result.append(details: Self.represent(request: request))
            result.append(involved: response)
            result.append(underlyingError: error)
        case .invalidResponse(let response, let request, let data, let error, let message):
            result.title = "Invalid response"
            result.append(details: message)
            if let data = data {
                if let payload = try? JSONDecoder().decode(Self.Payload.self, from: data) {
                    result.append(details: "Server error code: \(payload.code)")
                } else {
                    let representation = String(decoding: data, as: UTF8.self)
                    result.append(details: "Stringify payload: \(representation)")
                }
            }
            result.append(details: Self.represent(response: response))
            result.append(details: Self.represent(request: request))
            result.append(underlyingError: error)
        }
        
        return result.debugDescription
    }
}

extension API.Error {
    /// A typical server error payload.
    public struct Payload: Decodable {
        /// The server error code.
        public let code: String
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Self.CodingKeys.self)
            self.code = try container.decode(String.self, forKey: .code)
            
            let keys = container.allKeys
            guard keys.count == 1 else {
                let ctx = DecodingError.Context(codingPath: container.codingPath, debugDescription: "The server error payload (JSON) was expected to have only one key, but it has \(keys.count): \"\(keys.map { $0.rawValue }.joined(separator: ", "))\"")
                throw DecodingError.typeMismatch(Self.self, ctx)
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case code = "errorCode"
        }
    }
}

extension API.Error {
    /// "Stringify" the URL request.
    private static func represent(request: URLRequest) -> String {
        var result = "Request"
        
        if let method = request.httpMethod {
            result.append(" \(method)")
        }
        
        if let url = request.url {
            result.append(" \(url)")
        }
        
        if let headers = request.allHTTPHeaderFields {
            result.append("  keys: [")
            for (key, value) in headers {
                result.append("\(key): \(value), ")
            }
            result.removeLast(2)
            result.append("]")
        }
        
        if let data = request.httpBody {
            result.append(" body: ")
            result.append(String(decoding: data, as: UTF8.self))
        }
        
        return result
    }
    
    /// "Stringify" the URL response.
    private static func represent(response: HTTPURLResponse) -> String {
        var result = "Response code: \(response.statusCode)"
        
        guard let keys = response.allHeaderFields as? [String:String] else {
            fatalError("HTTP URL response keys couldn't be transformed to [String:String]. Source: \(response.allHeaderFields)")
        }
        guard !keys.isEmpty else {
            return result
        }
        
        result.append(", keys: [")
        for (key, value) in keys {
            result.append("\(key): \(value), ")
        }
        
        result.removeLast(2)
        result.append("]")
        return result
    }
}


