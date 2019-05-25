import Foundation

extension API {
    /// List of errors that can be generated through the API.
    public enum Error: Swift.Error, CustomDebugStringConvertible {
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
        
        public var debugDescription: String {
            var result = "\n\n"
            result.append("[API Error]")
            
            switch self {
            case .sessionExpired:
                result.addTitle("The session has expired.")
                result.addDetail("The underlying URL session or the \(API.self) instance cannot be found. You can probably solve this problem by creating a strong reference to the \(API.self) instance.")
            case .invalidCredentials(let credentials, let message):
                result.addTitle(message)
                result.addDetail(credentials) { "Please check the following credentials carefully:\n\($0)" }
            case .invalidRequest(let error, let message):
                result.addTitle(message)
                result.addDetail(error) { "error:\n\($0)" }
            case .callFailed(let request, let response, let error, let message):
                result.addTitle(message)
                result.addDetail("request: \(request.httpMethod?.uppercased() ?? "???") \(request)")
                result.addDetail(response) {"response: \($0.representation)"}
                result.addDetail(error) { "error:\n\($0)" }
            case .invalidResponse(let response, let request, let data, let error, let message):
                result.addTitle(message)
                result.addDetail("request: \(request.httpMethod?.uppercased() ?? "???") \(request)")
                result.addDetail("response: \(response.representation)")
                if let data = data {
                    result.addDetail("data [\(data)]")
                    if let representation = String(data: data, encoding: .utf8) {
                        result.append(": \(representation)")
                    }
                }
                result.addDetail(error) { "error:\n\($0)"}
            }
            
            result.append("\n\n")
            return result
        }
    }
}

extension DecodingError: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = "[Decoding Error]"
        let context: DecodingError.Context

        switch self {
        case .keyNotFound(let key, let ctx):
            result.addTitle("The key \"\(key.representation)\" was not found at path: \(ctx.codingPath.representation)")
            context = ctx
        case .valueNotFound(let type, let ctx):
            result.addTitle("A value of type \"\(type)\" was not found at path: \(ctx.codingPath.representation)")
            context = ctx
        case .dataCorrupted(let ctx):
            result.addTitle("Data being decoded is invalid at path: \(ctx.codingPath.representation)")
            context = ctx
        case .typeMismatch(let type, let ctx):
            result.addTitle("Value found is not of type \"\(type)\" at path: \(ctx.codingPath.representation)")
            context = ctx
        @unknown default:
            result.addTitle("Non-identified error. " + String(describing: self))
            return result
        }
        
        result.addDetail("message: \(context.debugDescription)")
        result.addDetail(context.underlyingError) { "error: \n\($0)" }
        return result
    }
}

private extension URLResponse {
    @objc var representation: String {
        return self.debugDescription
    }
}

private extension HTTPURLResponse {
    override var representation: String {
        let keys = self.allHeaderFields.keys.map { $0 as? String ?? "\($0)" }.joined(separator: ", ")
        return "\(self.statusCode) header keys [\(keys)]"
    }
}

private extension CodingKey {
    var representation: String {
        if let number = self.intValue {
            return String(number)
        } else {
            return self.stringValue
        }
    }
}

private extension Array where Array.Element == CodingKey {
    var representation: String {
        return self.map { $0.representation }.joined(separator: "/")
    }
}

internal extension String {
    /// Adds a title line to the error debug string.
    mutating func addTitle(_ message: String) {
        self.append(" " + message)
    }
    
    /// Adds a detail line to the error debug string.
    mutating func addDetail(_ message: String) {
        self.append("\n\t" + message)
    }
    
    /// Adds a detail line to the error debug string if the argument exists.
    mutating func addDetail<T>(_ instance: T?, _ messageGenerator: (T) -> String) {
        guard let instance = instance else { return }
        self.addDetail(messageGenerator(instance))
    }
}
