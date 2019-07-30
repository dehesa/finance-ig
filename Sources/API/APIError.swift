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
            result.append(error: error)
        case .callFailed(let request, let response, let error, let message):
            result.title = "Call failed"
            result.append(details: message)
            result.append(error: error)
            result.append(involved: request)
            result.append(involved: response)
        case .invalidResponse(let response, let request, let data, let error, let message):
            result.title = "Invalid response"
            result.append(details: message)
            result.append(error: error)
            result.append(involved: request)
            result.append(involved: response)
            result.append(involved: data)
        }
        
        return result.debugDescription
    }
}
