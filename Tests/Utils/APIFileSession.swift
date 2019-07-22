@testable import IG

/// Mocked URL Session that will pick responses from the bundle's file system.
final class APIFileSession: URLMockableSession {
    func dataTask(with request: URLRequest, completionHandler: @escaping DataTaskResult) -> URLMockableSessionDataTask {
        return APIFileSessionDataTask(with: request, completionHandler: completionHandler)
    }
    
    func invalidateAndCancel() {}
}

final class APIFileSessionDataTask: URLMockableSessionDataTask {
    let request: URLRequest
    fileprivate(set) var completionHandler: DataTaskResult?
    
    fileprivate init(with request: URLRequest, completionHandler: @escaping DataTaskResult) {
        self.request = request
        self.completionHandler = completionHandler
    }
    
    func resume() {
        let fileURL: URL = self.url(from: request)
        let data = try! Data(contentsOf: fileURL)
        let mock = try! JSONDecoder().decode(APIMockedJSON.self, from: data)
        let response = HTTPURLResponse(url: request.url!, statusCode: mock.statusCode, httpVersion: nil, headerFields: mock.header)!
        
        guard let body = mock.body else {
            return send(data: nil, response: response, error: nil)
        }
        
        let result = try! JSONEncoder().encode(body)
        return send(data: result, response: response, error: nil)
    }
    
    func suspend() {}
    
    func cancel() {}
}

extension APIFileSessionDataTask {
    /// Sends the given parameter as it was an URLSession.
    fileprivate func send(data: Data? = nil, response: URLResponse? = nil, error: Swift.Error? = nil) {
        guard let handler = completionHandler else { return }
        self.completionHandler = nil
        
        handler(data, response, error)
    }
    
    /// Transforms the request URL into a file URL.
    fileprivate func url(from request: URLRequest) -> URL {
        guard let url = request.url,
              let method = request.httpMethod,
              let header = request.allHTTPHeaderFields,
              let version = header[API.HTTP.Header.Key.version.rawValue] else {
            fatalError("The mocked fileURL couldn't be formed.")
        }
        
        /// Sometimes, IG has hidden the real HTTP method being used within the header.
        let prenom = header[API.HTTP.Header.Key._method.rawValue] ?? method
        let fileName = prenom.uppercased() + "_" + version
        let fileURL = url.appendingPathComponent(fileName).appendingPathExtension("json")
        
        // For now, delete the queries.
        guard var components = URLComponents(url: fileURL, resolvingAgainstBaseURL: true) else {
            fatalError("The mocked fileURL components couldn't be extracted.")
        }
        
        components.queryItems = nil
        guard let result = components.url else {
            fatalError("The mocked fileURL couldn't be formed.")
        }
        
        return result
    }
}
