import Foundation

extension URLRequest {
    /// Convenience function to set the HTTP method for the receiving URL request.
    internal mutating func setMethod(_ method: API.HTTP.Method) {
        self.httpMethod = method.rawValue
    }
    
    /// Convenience function to add header key/value pairs to a URL request header.
    /// - parameter version: The versioning number of the API endpoint being called.
    /// - parameter credentials: Credentials to access priviledge endpoints.
    /// - parameter headers: key/value pairs to be added as URL request headers.
    internal mutating func addHeaders(version: Int? = nil, credentials: API.Credentials? = nil, _ headers: [API.HTTP.Header.Key:String]? = nil) {
        if let version = version {
            self.addValue(String(version), forHTTPHeaderField: API.HTTP.Header.Key.version.rawValue)
        }
        
        if let credentials = credentials {
            for (k, v) in credentials.requestHeaders {
                self.addValue(v, forHTTPHeaderField: k.rawValue)
            }
        }
        
        if let headers = headers {
            for (key, value) in headers {
                self.addValue(value, forHTTPHeaderField: key.rawValue)
            }
        }
    }
    
    /// Serialize as JSON data and add the passed parameter to the receiving request body.
    /// - parameter body: The Swift types to be serialized into JSON data.
    /// - throws: `API.Error.invalidRequest` only.
    internal mutating func attachJSON<T:Encodable>(_ body: T, with encoder: JSONEncoder) throws {
        do {
            // self.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            self.httpBody = try encoder.encode(body)
        } catch let error {
            throw API.Error.invalidRequest(underlyingError: error, message: "The provided body for the request couldn't be serialized. Body:\n\(body)")
        }
        
        self.addValue(API.HTTP.Header.Value.ContentType.json.rawValue, forHTTPHeaderField: API.HTTP.Header.Key.requestType.rawValue)
    }
}
