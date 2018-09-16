import ReactiveSwift
import Result
import Foundation

/// The API instance is the bridge to the HTTP endpoints provided by the platform.
///
/// It allows you to authenticate on the platforms and it stores the credentials for priviledge endpoints (which are most of them).
/// APIs where there are no explicit `note` in the documentation require stored credentials.
/// - note: You can create as many API instances as you want, but each instance contains its on URL Session; thus you may want to have a single API instance doing all your endpoint calling.
public final class API {
    /// Session credentials used to call priviledge endpoints.
    private var sessionCredentials: API.Credentials?
    /// The URL Session instance for performing HTTPS requests.
    fileprivate let sessionURL: URLMockableSession
    /// URL root address.
    public let rootURL: URL
    
    /// Designated initializer allowing you to change the internal URL session.
    ///
    /// This initializer is used on testing purposes; that is why is marked with `internal` access.
    /// - parameter rootURL: The base/root URL for all endpoint calls.
    /// - parameter session: URL session used to perform all HTTP requests.
    internal init(rootURL: URL, session: URLMockableSession, credentials: API.Credentials? = nil) {
        self.rootURL = rootURL
        self.sessionURL = session
        self.sessionCredentials = credentials
    }
    
    /// Initializer for an API instance, giving you the default options.
    /// - parameter rootURL: The base/root URL for all endpoint calls.
    /// - parameter credentials: `nil` for yet unknown credentials (most of the cases); otherwise, use your hard-coded credentials.
    /// - parameter configurations: URL session configuration properties. By default, you get a non-cached, non-cookies, pipeline and secure URL session configuration.
    public convenience init(rootURL: URL, credentials: API.Credentials?, configurations: URLSessionConfiguration = API.defaultSessionConfigurations) {
        self.init(rootURL: rootURL, session: URLSession(configuration: configurations), credentials: credentials)
    }
    
    deinit {
        self.sessionURL.invalidateAndCancel()
    }

    /// Returns credentials needed on most API endpoints.
    /// - returns: Session credentials (whether CST or OAuth).
    /// - throws: `API.Error.invalidCredentials` if there were no credentials stored.
    public func credentials() throws -> API.Credentials {
        return try self.sessionCredentials ?! API.Error.invalidCredentials(nil, message: "No credentials found.")
    }
    
    /// Updates the current credentials (if any) with a new set of credentials.
    /// - parameter credentials: The new set of credentials to be stored within this API instance.
    public func updateCredentials(_ credentials: API.Credentials) {
        self.sessionCredentials = credentials
    }
    
    /// Removes the current credentials (leaving none behind).
    ///
    /// After the call to this method, no endpoint requiring credentials can be executed.
    public func removeCredentials() {
        self.sessionCredentials = nil
    }
    
    /// Default configuration for the underlying URLSession
    public static var defaultSessionConfigurations: URLSessionConfiguration {
        return URLSessionConfiguration.ephemeral.set {
            $0.networkServiceType = .default
            $0.allowsCellularAccess = true
            $0.httpCookieAcceptPolicy = .never
            $0.httpCookieStorage = nil
            $0.httpShouldSetCookies = false
            $0.httpShouldUsePipelining = true
            $0.urlCache = nil
            $0.requestCachePolicy = .reloadIgnoringLocalCacheData
            $0.waitsForConnectivity = false
            $0.tlsMinimumSupportedProtocol = .tlsProtocol12
        }
    }
    
    /// List of request data needed to make endpoint calls.
    public enum Request {}
    /// List of responses received from endpoint calls.
    public enum Response {}
}

extension API {
    /// Internal typealias for API requests.
    internal typealias InternalRequest = (request: URLRequest, api: API)
    /// Internal typealias for request responses.
    internal typealias InternalResponse = (request: URLRequest, header: HTTPURLResponse, data: Data?)
    /// Internal typealias for request responses (with data).
    internal typealias InternalResponseData = (request: URLRequest, header: HTTPURLResponse, data: Data)
    
    /// The callback provided in this function will generate an `URLRequest` that will be performed when the resulting `SignalProducer` is started.
    ///
    /// When the SignalProducer is started, the request will be generated (not before) and the API URLSession where the request will be executed is passed along.
    /// - parameter urlRequest: The callback actually creating the `URLRequest`.
    ///  - parameter api: The API instance where usually credentials an other temporal priviledge information is being retrieved.
    /// - returns: New `SignalProducer` returning the request and the API instance.
    /// - seealso: URLRequest
    internal func makeRequest(_ request: @escaping (_ api: API) throws -> URLRequest) -> SignalProducer<API.InternalRequest,API.Error> {
        return SignalProducer { [weak self, requestGenerator = request] (input, _) in
            guard let self = self else {
                return input.send(error: .sessionExpired)
            }
            
            let urlRequest: URLRequest
            do {
                urlRequest = try requestGenerator(self)
            } catch let error as API.Error {
                return input.send(error: error)
            } catch let error {
                return input.send(error: .invalidRequest(underlyingError: error, message: "The URL request couldn't be formed."))
            }
            
            input.send(value: (urlRequest, self))
            input.sendCompleted()
        }
    }
    
    /// Used when generating the queries of an URL Request.
    internal typealias RequestQueryGenerator = () throws -> [URLQueryItem]
    /// Used when generating the json body of an URL Request.
    internal typealias RequestBodyGenerator  = () throws -> (contentType: API.HTTP.Header.Value.ContentType, data: Data)
    
    /// Convenience function over the regular `makeRequest(_:)` placing the most common parameters.
    ///
    /// Please note, this is purely a convenience function, for request that fall (even slightly) outside the given parameters, the other `makeRequest(_:)` function shall be used.
    /// - parameter method: The HTTP method of the endpoint.
    /// - parameter relativeURL: The relative URL to be appended to the API instance root URL.
    /// - parameter usingCredentials: Whether the request shall include credential headers.
    /// - parameter queries: Optional array of queries to be attached to the request.
    /// - parameter headers: Additional headers to be included in the request.
    /// - parameter body: Optional body generator to include in the request.
    internal func makeRequest(_ method: API.HTTP.Method, _ relativeURL: String, version: Int, credentials usingCredentials: Bool, queries: RequestQueryGenerator? = nil, headers: [API.HTTP.Header.Key:String]? = nil, body: RequestBodyGenerator? = nil) -> SignalProducer<API.InternalRequest,API.Error> {
        return SignalProducer { [weak self] (input, _) in
            guard let self = self else {
                return input.send(error: .sessionExpired)
            }
            
            var url = self.rootURL.appendingPathComponent(relativeURL)
            
            // If there are queries to append, enter this block; if not, ignore it.
            if let queryGenerator = queries {
                let urlQueries: [URLQueryItem]
                do {
                    urlQueries = try queryGenerator()
                } catch let error as API.Error {
                    return input.send(error: error)
                } catch let error {
                    return input.send(error: .invalidRequest(underlyingError: error, message: "The URL request queries couldn't be formed."))
                }

                if !urlQueries.isEmpty {
                    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
                        return input.send(error: .invalidRequest(underlyingError: nil, message: "The URL \"\(url)\" cannot be transformed into URL components."))
                    }
                    
                    components.queryItems = urlQueries
                    guard let requestURL = components.url else {
                        return input.send(error: .invalidRequest(underlyingError: nil, message: "The URL couldn't be formed"))
                    }
                    url = requestURL
                }
            }
            
            // Generate the result URLRequest.
            var request = URLRequest(url: url)
            request.setMethod(method)
            
            do {
                let credentials: API.Credentials? = (usingCredentials) ? try self.credentials() : nil
                request.addHeaders(version: version, credentials: credentials, headers)
                
                if let bodyGenerator = body {
                    let blob = try bodyGenerator()
                    request.addValue(blob.contentType.rawValue, forHTTPHeaderField: API.HTTP.Header.Key.requestType.rawValue)
                    request.httpBody = blob.data
                }
            } catch let error as API.Error {
                return input.send(error: error)
            } catch let error {
                return input.send(error: .invalidRequest(underlyingError: error, message: "The request couldn't be formed."))
            }
            
            input.send(value: (request, self))
            return input.sendCompleted()
        }
    }
    
    /// Takes a `URLRequest` and send it, expecting to receive a paginated JSON. If more pages are available, those are requested serially.
    /// - parameter requestGenerator: Block that generates an URLRequest or fail throwing an `API.Error` error. Only those errors are expected, any other will crash the program.
    /// - parameter expectedStatusCodes: Any of the status codes expected on the HTTP responses.
    /// - parameter decoder: Block generating the JSON Decoder for the response payload.
    /// - parameter valueHandler: When a value is returned, this handler will decide which events to forward and whether the following page should be requested. If a forwarded event is *terminating*, no further processing will be performed.
    ///  - parameter page: Page received.
    internal func paginatedRequest<PT:Decodable,T>(request requestGenerator: @escaping (_ api: API) throws -> URLRequest, expectedStatusCodes: [Int]? = [200], decoder: @escaping API.Codecs.DecoderGenerator = API.Codecs.jsonDecoder, _ valueHandler: @escaping (_ api: API, _ page: Signal<PT,API.Error>.Value) -> ([Signal<T,API.Error>.Event],URLRequest?)) -> SignalProducer<T,API.Error> {
        return SignalProducer<T,API.Error> { [weak weakAPI = self] (generator, lifetime) in
            /// First request on the paginated stream.
            let primalRequest: URLRequest
            guard let primalAPI = weakAPI else { return generator.send(error: .sessionExpired) }
            
            do {
                primalRequest = try requestGenerator(primalAPI)
            } catch let error {
                return generator.send(error: error as! API.Error)
            }
            
            typealias SignalPT = Signal<PT,API.Error>
            typealias SignalT = Signal<T,API.Error>
            
            /// Handler for paginated responses (including the first one).
            var signalHandler: SignalPT.Observer.Action! = nil
            /// Append to the signal pipeline the send, validate, decode, and handle stages.
            let executeRequest: (SignalProducer<API.InternalRequest,API.Error>) -> Void = { (signal) in
                let disposable = signal
                    .send(expecting: .json)
                    .validateLadenData(statusCodes: expectedStatusCodes)
                    .decodeJSON(generator: decoder)
                    .start(signalHandler)
                lifetime.observeEnded(disposable.dispose)
            }
            
            signalHandler = { (event: SignalPT.Event) in
                let page: PT
                switch event {
                case .completed: return
                case .interrupted: return generator.sendInterrupted()
                case .failed(let e): return generator.send(error: e)
                case .value(let p): page = p
                }
                
                guard let futureAPI = weakAPI else { return generator.send(error: .sessionExpired) }
                let next: (events: [SignalT.Event], request: URLRequest?) = valueHandler(futureAPI, page)
                
                for e in next.events {
                    generator.send(e)
                    if e.isTerminating { return }
                }
                
                guard let request = next.request else {
                    return generator.sendCompleted()
                }
                
                executeRequest(SignalProducer(value: (request, futureAPI)))
            }
            
            executeRequest(SignalProducer(value: (primalRequest, primalAPI)))
        }
    }
}

extension SignalProducer where Value==API.InternalRequest, Error==API.Error {
    /// Executes (on a `SignalProducer`) the `API.InternalRequest` passed as value and returns the `API.InternalResponse`.
    /// - parameter type: The content type expected as a result.
    /// - returns: A new `SignalProducer` with the response of the executed enpoint.
    internal func send(expecting type: API.HTTP.Header.Value.ContentType? = nil) -> SignalProducer<API.InternalResponse,API.Error> {
        return self.flatMap(.latest) { (r, api) -> SignalProducer<API.InternalResponse,Error> in
            weak var weakSession = api.sessionURL
            return SignalProducer<API.InternalResponse,API.Error> { (generator, lifetime) in
                var request = r
                if let contentType = type {
                    request.addHeaders([.responseType: contentType.rawValue])
                }
                
                guard let session = weakSession else {
                    return generator.send(error: .sessionExpired)
                }
                
                let task = session.dataTask(with: request) { (data, response, error) in
                    if let error = error {
                        return generator.send(error: .callFailed(request: request, response: response, underlyingError: error, message: "The HTTP request failed."))
                    }

                    guard let header = response as? HTTPURLResponse else {
                        return generator.send(error: .callFailed(request: request, response: response, underlyingError: nil, message: "The URL response couldn't be parsed to a HTTP URL Response."))
                    }

                    generator.send(value: (request,header,data))
                    generator.sendCompleted()
                }
                
                let _ = lifetime.observeEnded { [weak task] in
                    task?.cancel()
                }
                task.resume()
            }
        }
    }
}

extension SignalProducer where Value==API.InternalResponse, Error==API.Error {
    /// Checks that the returned response is within the accepted given `statusCodes`.
    /// - parameter statusCodes: All supported status codes.
    internal func validate(statusCodes: [Int]) -> SignalProducer<Value,Error> {
        return self.attemptMap { (request, header, data) -> Result<Value,API.Error> in
            guard statusCodes.contains(header.statusCode) else {
                let error: API.Error = .invalidResponse(header, request: request, data: data, underlyingError: nil, message: "Status code validation failed.\n\tExpected: \(statusCodes).\n\tReceived: \(header.statusCode).")
                return .failure(error)
            }
            
            return .success((request,header,data))
        }
    }
    
    /// Checks that the returned response has a non-empty data body. Optionally, it can check for status codes (similarly to `validate(statusCodes:)`.
    /// - parameter statusCode: If not `nil`, the array indicates all *viable*/supported status codes.
    internal func validateLadenData(statusCodes: [Int]? = nil) -> SignalProducer<API.InternalResponseData,Error> {
        return self.attemptMap { (request, header, data) -> Result<API.InternalResponseData,API.Error> in
            if let codes = statusCodes, !codes.contains(header.statusCode) {
                let error: API.Error = .invalidResponse(header, request: request, data: data, underlyingError: nil, message: "Status code validation failed.\n\tExpected: \(codes).\n\tReceived: \(header.statusCode).")
                return .failure(error)
            }
            
            guard let data = data else {
                let error: API.Error = .invalidResponse(header, request: request, data: nil, underlyingError: nil, message: "Response was expected to contained a body, but no data was found.")
                return .failure(error)
            }
            
            return .success((request, header, data))
        }
    }
}

extension SignalProducer where Value==API.InternalResponseData, Error==API.Error {
    /// Decodes the JSON payload with a given `JSONDecoder`.
    /// - parameter generator: Callback receiving the url request and HTTP header. It must return the JSON decoder to actually decode the data.
    internal func decodeJSON<T:Decodable>(generator: @escaping API.Codecs.DecoderGenerator = API.Codecs.jsonDecoder) -> SignalProducer<T,API.Error> {
        return self.attemptMap { (request, header, data) -> Result<T,API.Error> in
            let decoder = generator(request,header)
            do {
                return .success(try decoder.decode(T.self, from: data))
            } catch let e {
                // print("\n\n\(String(data: data, encoding: .utf8)!)\n\n")
                let error: API.Error = .invalidResponse(header, request: request, data: data, underlyingError: e, message: "The response body could not be parsed to the expected type: \"\(T.self)\".")
                return .failure(error)
            }
        }
    }
}

extension SignalProducer where Error==API.Error {
    /// Convenience function that creates a weak bond with the API instance and every time is executed/started, checks whether the instance is still there; if so, it proceeds; if not, it generates an error.
    /// - parameter api: The API instance containing the URL Session. A weak bond is created.
    /// - parameter strategy: Signal flatmap strategy to be used to concatenate the call.
    /// - parameter next: The endpoint to be called on a successful value from the receiving signal.
    public func call<V>(on api: API, strategy: FlattenStrategy = .latest, _ next: @escaping (API,Value)->SignalProducer<V,API.Error>) -> SignalProducer<V,API.Error> {
        return self.flatMap(strategy) { [weak weakAPI = api] (receivedValue) -> SignalProducer<V,API.Error> in
            guard let api = weakAPI else { return SignalProducer<V,API.Error>(error: .sessionExpired) }
            return next(api, receivedValue)
        }
    }
}
