import Foundation
import ReactiveSwift

// MARK: - Request types

extension API.Request {
    /// Request values that have been verified/validated.
    internal struct ValidatedValues<T> {
        /// An API instance that hasn't expired yet.
        let api: API
        /// Values that have been validated.
        let values: T
        
        /// Designated initializer.
        /// - parameter api: Instance in charge of performing the request.
        /// - parameter values: The values that will "somehow" be added to the request.
        init(_ api: API, validated values: T) {
            self.api = api
            self.values = values
        }
    }
    
    /// List of typealias representing closures which generate a specific data type.
    internal enum Generator {
        /// Closure receiving a valid API session and returning validated values.
        /// - parameter api: The API instance from where credentials an other temporal priviledge information is being retrieved.
        /// - returns: The validated values.
        typealias Validation<T> = (_ api: API) throws -> T
        /// Closure which returns a newly created `URLRequest` and provides with it an API instance.
        /// - parameter api: The API instance from where credentials an other temporal priviledge information is being retrieved.
        /// - parameter values: Values that have been validated in a previous step.
        /// - returns: A newly created `URLRequest`.
        internal typealias Request<T> = (_ api: API, _ values: T) throws -> URLRequest
        /// Closure which returns a bunch of query items to be used in a `URLRequest`.
        /// - parameter api: The API instance from where credentials an other temporal priviledge information is being retrieved.
        /// - parameter values: Values that have been validated in a previous step.
        /// - returns: Array of `URLQueryItem`s to be added to a `URLRequest`.
        internal typealias Query<T> = (_ api: API, _ values: T) throws -> [URLQueryItem]
        /// Closure which returns a bunch of header key-values to be used in a `URLRequest`.
        /// - parameter api: The API instance from where credentials an other temporal priviledge information is being retrieved.
        /// - parameter values: Values that have been validated in a previous step.
        /// - returns: Key-value pairs to be added to a `URLRequest`.
        internal typealias Header<T> = (_ api: API, _ values: T) throws -> [API.HTTP.Header.Key:String]
        /// Closure which returns a body to be appended to a `URLRequest`.
        /// - parameter api: The API instance from where credentials an other temporal priviledge information is being retrieved.
        /// - parameter values: Values that have been validated in a previous step.
        /// - returns: Tuple containing information about what type of body has been compiled and its data.
        internal typealias Body<T>  = (_ api: API, _ values: T) throws -> (contentType: API.HTTP.Header.Value.ContentType, data: Data)
        /// Closure which given a request and its actual response, generates a JSON decoder (typically to decode the responses payload).
        /// - parameter request: The URL request that returned the `response`.
        /// - parameter response: The HTTP response received from the execution of `request`.
        /// - returns: A JSON decoder (to typically decode the response's payload).
        typealias Decoder = (_ request: URLRequest, _ response: HTTPURLResponse) -> JSONDecoder
    }
    
    /// Wrapper around a `URLRequest` and the API instance that will (most probably) execute such request.
    /// - returns: A `URLRequest` and an `API` instance.
    internal typealias Wrapper = (api: API, request: URLRequest)
}

// MARK: - Response types

extension API.Response {
    /// Wrapper around a `URLRequest` and the received `HTTPURLResponse` and optional data payload.
    internal typealias Wrapper = (request: URLRequest, header: HTTPURLResponse, data: Data?)
    /// Wrapper around a `URLRequest` and the received `HTTPURLResponse` and a data payload.
    internal typealias DataWrapper = (request: URLRequest, header: HTTPURLResponse, data: Data)
}

// MARK: - SignalProducers

extension SignalProducer where Value==API.Request.ValidatedValues<Void>, Error==API.Error {
    /// Initializes a `SignalProducer` that checks (when started) whether the passed API session has expired.
    /// - attention: This initializer creates a weak bond with the  API instance passed as argument. When the `SignalProducer` is started, the bond will be tested and if the instance is `nil`, the `SignalProducer` will generate an error event.
    /// - parameter api: The API session where API calls will be performed.
    internal init(api: API) {
        self.init { [weak api] (input, _) in
            guard let api = api else {
                return input.send(error: .sessionExpired)
            }
            
            input.send(value: .init(api, validated: ()))
            input.sendCompleted()
        }
    }
}

extension SignalProducer where Error==API.Error {
    /// Initializes a `SignalProducer` that checks (when started) whether the passed API session has expired. It will also execute the `validating` closure and pass those values to the following step.
    /// - attention: This function makes a weak bond with the receiving API instance. When the `SignalProducer` is started, the bond will be tested and if the instance is `nil`, the `SignalProducer` will generate an error event.
    /// - parameter api: The API session where API calls will be performed.
    /// - parameter validating: Closure validating some values that will pass with the signal event to the following step.
    internal init<T>(api: API, validating: @escaping API.Request.Generator.Validation<T>) where SignalProducer.Value==API.Request.ValidatedValues<T> {
        self.init { [weak api, validating] (input, _) in
            guard let api = api else {
                return input.send(error: .sessionExpired)
            }
            
            let values: T
            do {
                values = try validating(api)
            } catch let error as API.Error {
                return input.send(error: error)
            } catch let error {
                return input.send(error: .invalidRequest(underlyingError: error, message: "The request validation failed."))
            }
            
            input.send(value: .init(api, validated: values))
            input.sendCompleted()
        }
    }
    
    /// Generates a `SignalProducer` that when started, it will produce an event with the result of the closure provided in the parameter.
    ///
    /// It will then immediately complete.
    /// - parameter requestor: The callback actually creating the `URLRequest`.
    /// - returns: New `SignalProducer` returning the request and the API instance.
    /// - seealso: URLRequest
    internal func request<T>(_ requestor: @escaping API.Request.Generator.Request<T>) -> SignalProducer<API.Request.Wrapper,API.Error> where Value==API.Request.ValidatedValues<T> {
        return self.attemptMap { [requestor] (validated) -> Result<API.Request.Wrapper,API.Error> in
            let request: URLRequest
            do {
                request = try requestor(validated.api, validated.values)
            } catch let error as API.Error {
                return .failure(error)
            } catch let error {
                return .failure(.invalidRequest(underlyingError: error, message: "The URL request couldn't be formed."))
            }
            
            return .success( (validated.api, request) )
        }
    }
    
    /// Convenience function over the regular `request(_:)` placing the most common parameters.
    ///
    /// Please note that this is purely a convenience function, for requests that fall (even slightly) outside the given parameters, the other `request(_:)` function shall be used.
    /// - attention: This function makes a weak bond with the receiving API instance. When the `SignalProducer` is started, the bond will be tested and if the instance is `nil`, the `SignalProducer` will generate an error event.
    /// - parameter method: The HTTP method of the endpoint.
    /// - parameter relativeURL: The relative URL to be appended to the API instance root URL.
    /// - parameter version: The API endpoint version number (to be included in the HTTP header).
    /// - parameter usingCredentials: Whether the request shall include credential headers.
    /// - parameter queryGenerator: Optional array of queries to be attached to the request.
    /// - parameter headerGenerator: Additional headers to be included in the request.
    /// - parameter bodyGenerator: Optional body generator to include in the request.
    /// - returns: `SignalProducer` wrapping all the data of a proper HTTP request (`URLRequest`) and a weak link to the API instance that will execute the provided request.
    internal func request<T>(_ method: API.HTTP.Method, _ relativeURL: String, version: Int, credentials usingCredentials: Bool,
                             queries queryGenerator: API.Request.Generator.Query<T>? = nil,
                             headers headerGenerator: API.Request.Generator.Header<T>? = nil,
                             body bodyGenerator: API.Request.Generator.Body<T>? = nil
                            ) -> SignalProducer<API.Request.Wrapper,API.Error>  where Value==API.Request.ValidatedValues<T> {
        return self.attemptMap { (validated) -> Result<API.Request.Wrapper,API.Error> in
            // Generate the absolute URL.
            var url = validated.api.rootURL.appendingPathComponent(relativeURL)
            
            // If there are queries to append, enter this block; if not, ignore it.
            if let queryGenerator = queryGenerator {
                let queries: [URLQueryItem]
                do {
                    queries = try queryGenerator(validated.api, validated.values)
                } catch let error as API.Error {
                    return .failure(error)
                } catch let error {
                    return .failure(.invalidRequest(underlyingError: error, message: "The URL request queries couldn't be formed."))
                }
                
                if !queries.isEmpty {
                    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
                        return .failure(.invalidRequest(underlyingError: nil, message: "The URL \"\(url)\" cannot be transformed into URL components."))
                    }
                    
                    components.queryItems = queries
                    guard let requestURL = components.url else {
                        return .failure(.invalidRequest(underlyingError: nil, message: "The URL couldn't be formed"))
                    }
                    url = requestURL
                }
            }
            
            // Generate the result URLRequest.
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue
            
            do {
                if usingCredentials {
                    guard let credentials = validated.api.session.credentials else {
                        return .failure(.invalidCredentials(nil, message: "No credentials found."))
                    }
                    request.addHeaders(version: version, credentials: credentials, try headerGenerator?(validated.api, validated.values))
                }
                
                if let bodyGenerator = bodyGenerator {
                    let body = try bodyGenerator(validated.api, validated.values)
                    request.addValue(body.contentType.rawValue, forHTTPHeaderField: API.HTTP.Header.Key.requestType.rawValue)
                    request.httpBody = body.data
                }
            } catch let error as API.Error {
                return .failure(error)
            } catch let error {
                return .failure(.invalidRequest(underlyingError: error, message: "The request couldn't be formed."))
            }
            
            return .success( (validated.api, request) )
        }
    }
}

extension SignalProducer where Value==API.Request.Wrapper, Error==API.Error {
    /// Executes (on a `SignalProducer`) the passed request on the passed API instance, returning the endpoint result.
    /// - parameter type: The content type expected as a result.
    /// - returns: A new `SignalProducer` with the response of the executed enpoint.
    internal func send(expecting type: API.HTTP.Header.Value.ContentType? = nil) -> SignalProducer<API.Response.Wrapper,API.Error> {
        return self.flatMap(.merge) { (api, urlRequest) -> SignalProducer<API.Response.Wrapper,Error> in
            return SignalProducer<API.Response.Wrapper,API.Error> { (generator, lifetime) in
                var request = urlRequest
                if let contentType = type {
                    request.addHeaders([.responseType: contentType.rawValue])
                }
                
                /// Disposable used to detach the actual download task from the resulting signal's lifetime.
                ///
                /// When `dispose()` is called here the strong cycle to the download task will be removed.
                /// - note: The task WON'T be cancelled by calling `dispose()`
                var detacher: Disposable?

                let task = api.channel.dataTask(with: request) { [request, generator] (data, response, error) in
                    detacher?.dispose()
                    
                    if let error = error {
                        return generator.send(error: .callFailed(request: request, response: response, underlyingError: error, message: "The HTTP request failed."))
                    }

                    guard let header = response as? HTTPURLResponse else {
                        return generator.send(error: .callFailed(request: request, response: response, underlyingError: nil, message: "The URL response couldn't be parsed to a HTTP URL Response."))
                    }

                    generator.send(value: (request,header,data))
                    generator.sendCompleted()
                }

                detacher = lifetime.observeEnded { task.cancel() }
                task.resume()
            }
        }
    }
    
    internal typealias PreviousEndpoint<M> = (request: URLRequest, meta: M)
    
    /// Similar than `send(expecting:)`, this method executes one (or many) requests on the passed API instance.
    ///
    /// The initial request is received as a value and is evaluated on the `intermediateRequest` closure. If the closure returns a `URLRequest`, that endpoint will be performed. If the closure returns `nil`, the signal producer will complete.
    /// - parameter intermediateRequest: All data needed to compile a request for the next page. If `nil` is returned, the request won't be performed and the signal will complete. On the other hand, if an error is thrown (which will be forced cast to `API.Error`), it will be forwarded as a failure event.
    /// - parameter endpoint: A paginated request response. The values/errors will be forwarded to the returned producer.
    /// - returns: A `SignalProducer` returning the values from `endpoint` as soon as they arrive. Only when `nil` is returned on the `request` closure, will the returned producer complete.
    internal func paginate<M,R>(request intermediateRequest: @escaping (_ api: API, _ initialRequest: URLRequest, _ previous: PreviousEndpoint<M>?) throws -> URLRequest?,
                                endpoint: @escaping (_ requestSignal: SignalProducer<Value,Error>) -> SignalProducer<(M,R),API.Error>
                               ) -> SignalProducer<R,Error> {
        return self.flatMap(.merge) { (api, initialRequest) in
            return SignalProducer<R,Error> { (generator, lifetime) in
                /// Recursive closure fed with the latest endpoint call (or `nil`) at the very beginning.
                var iterator: ( (_ previous: PreviousEndpoint<M>?) -> Void )! = nil
                /// Disposable used to detached the current page download task from the resulting signal's lifetime.
                var detacher: Disposable? = nil
                
                iterator = { (previous) in
                    detacher?.dispose()
                    
                    let paginatedRequest: URLRequest?
                    do {
                        paginatedRequest = try intermediateRequest(api, initialRequest, previous)
                    } catch let error as API.Error {
                        return generator.send(error: error)
                    } catch let error {
                        return generator.send(error: .invalidRequest(underlyingError: error, message: "The paginated request couldn't be formed."))
                    }
                    
                    guard let request = paginatedRequest else {
                        return generator.sendCompleted()
                    }
                    
                    let producer = SignalProducer<Value,Error>(value: (api, request))
                    detacher = lifetime += endpoint(producer).start { (event) in
                        switch event {
                        case .value((let meta, let value)):
                            generator.send(value: value)
                            return iterator((request, meta))
                        case .completed:
                            return
                        case .failed(let error):
                            return generator.send(error: error)
                        case .interrupted:
                            return generator.sendInterrupted()
                        }
                    }
                }
                
                iterator(nil)
            }
        }
    }
}

extension SignalProducer where Value==API.Response.Wrapper, Error==API.Error {
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
    internal func validateLadenData(statusCodes: [Int]? = nil) -> SignalProducer<API.Response.DataWrapper,Error> {
        return self.attemptMap { (request, header, data) -> Result<API.Response.DataWrapper,API.Error> in
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

extension SignalProducer where Value==API.Response.DataWrapper, Error==API.Error {
    /// Decodes the JSON payload with a given `JSONDecoder`.
    /// - parameter decoderGenerator: Callback receiving the url request and HTTP header. It must return the JSON decoder to actually decode the data.
    internal func decodeJSON<T:Decodable>(with decoderGenerator: @escaping API.Request.Generator.Decoder = API.Codecs.jsonDecoder) -> SignalProducer<T,API.Error> {
        return self.attemptMap { (request, header, data) -> Result<T,API.Error> in
            let decoder = decoderGenerator(request,header)
            do {
                return .success(try decoder.decode(T.self, from: data))
            } catch let e {
                // print("\n\n\(String(data: data, encoding: .utf8)!)\n\n")
                let error: API.Error = .invalidResponse(header, request: request, data: data, underlyingError: e, message: #"The response body could not be parsed to the expected type: "\#(T.self)"."#)
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
        return self.flatMap(strategy) { [weak api] (receivedValue) -> SignalProducer<V,API.Error> in
            guard let api = api else { return SignalProducer<V,API.Error>(error: .sessionExpired) }
            return next(api, receivedValue)
        }
    }
}
