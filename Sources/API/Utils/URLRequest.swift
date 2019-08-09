import Foundation

extension URLRequest {
    /// Convenience function to append the given URL queries to the receiving URL request.
    /// - parameter newQueries: URL queries to be appended at the end of the given URL.
    /// - throws: `API.Error` of `.invalidRequest` type if the receiving request have no URL (or cannot be transformed into `URLComponents`) or the given queries cannot be appended to the receiving request URL.
    internal mutating func addQueries(_ newQueries: [URLQueryItem]) throws {
        guard !newQueries.isEmpty else {
            return
        }
        
        guard let previousURL = self.url else {
            let message = "New queries couldn't be appended to a receiving request, since the request URL was found empty."
            throw API.Error.invalidRequest(message, request: self, suggestion: API.Error.Suggestion.readDocumentation)
        }
        
        guard var components = URLComponents(url: previousURL, resolvingAgainstBaseURL: true) else {
            let message = #"New queries couldn't be appended to a receiving request, since the request URL cannot be transmuted into "URLComponents"."#
            throw API.Error.invalidRequest(message, request: self, suggestion: API.Error.Suggestion.readDocumentation)
        }
        
        if let previousQueries = components.queryItems {
            // If there are previous queries, replace previous query names by the new ones.
            var result: [URLQueryItem] = []
            for previousQuery in previousQueries where !newQueries.contains(where: { $0.name == previousQuery.name }) {
                result.append(previousQuery)
            }
            
            result.append(contentsOf: newQueries)
            components.queryItems = result
        } else {
            components.queryItems = newQueries
        }
        
        guard let url = components.url else {
            let message = "A new URL from the previous request and the given queries couldn't be formed."
            let representation = newQueries.map { "\($0.name): \($0.value ?? "")" }.joined(separator: ", ")
            
            var error: API.Error = .invalidRequest(message, request: self, suggestion: API.Error.Suggestion.readDocumentation)
            error.context.append(("Queries", representation))
            throw error
        }
        self.url = url
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
    ///
    /// This convenience function will both replace the receiving request HTTP body with the encoded argument and will set the receiving request header content type to indicate the body contains a JSON payload.
    /// - parameter body: The Swift types to be serialized into JSON data.
    /// - parameter encoder: The JSON encoder  used to serialize the given type.
    /// - throws: `API.Error.invalidRequest` if the given argument couldn't be serialized. The API error will wrap the encoding error.
    internal mutating func attachJSON<T:Encodable>(_ body: T, with encoder: JSONEncoder) throws {
        do {
            self.httpBody = try encoder.encode(body)
        } catch let error {
            let message = #"The provided body (of type "\#(T.self)") for the request couldn't be serialized."#
            throw API.Error.invalidRequest(message, request: self, underlying: error, suggestion: API.Error.Suggestion.readDocumentation)
        }
        
        self.addValue(API.HTTP.Header.Value.ContentType.json.rawValue, forHTTPHeaderField: API.HTTP.Header.Key.requestType.rawValue)
    }
}

// MARK: - Debug Helpers

extension URLRequest {
    internal var debugDescription: String {
        var result = "\(self.httpMethod ?? "nil") \(self.description)\n"
        if let headers = self.allHTTPHeaderFields {
            for header in headers {
                result.append("\t\(header.key): \(header.value)\n")
            }
        }
        return result
    }
}
