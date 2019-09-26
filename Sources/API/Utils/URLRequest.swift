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
            let message = "New queries couldn't be appended to a receiving request, since the request URL was found empty"
            throw IG.API.Error.invalidRequest(.init(message), request: self, suggestion: .readDocs)
        }
        
        guard var components = URLComponents(url: previousURL, resolvingAgainstBaseURL: true) else {
            let message = #"New queries couldn't be appended to a receiving request, since the request URL cannot be transmuted into "URLComponents""#
            throw IG.API.Error.invalidRequest(.init(message), request: self, suggestion: .readDocs)
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
            let message = "A new URL from the previous request and the given queries couldn't be formed"
            let representation = newQueries.map { "\($0.name): \($0.value ?? "")" }.joined(separator: ", ")
            
            var error: IG.API.Error = .invalidRequest(.init(message), request: self, suggestion: .readDocs)
            error.context.append(("Queries", representation))
            throw error
        }
        self.url = url
    }
    
    /// Convenience function to add header key/value pairs to a URL request header.
    /// - parameter version: The versioning number of the API endpoint being called.
    /// - parameter credentials: Credentials to access priviledge endpoints.
    /// - parameter headers: key/value pairs to be added as URL request headers.
    internal mutating func addHeaders(version: Int? = nil, credentials: IG.API.Credentials? = nil, _ headers: [IG.API.HTTP.Header.Key:String]? = nil) {
        if let version = version {
            self.addValue(String(version), forHTTPHeaderField: IG.API.HTTP.Header.Key.version.rawValue)
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
}
