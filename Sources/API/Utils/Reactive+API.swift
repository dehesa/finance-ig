import Foundation
import ReactiveSwift

extension SignalProducer where Value==API.Request.WrapperValid<Void>, Error==API.Error {
    /// Initializes a `SignalProducer` that checks (when started) whether the passed API session has expired.
    /// - attention: This initializer creates a weak bond with the  API instance passed as argument. When the `SignalProducer` is started, the bond will be tested and if the instance is `nil`, the `SignalProducer` will generate an error event.
    /// - parameter api: The API session where API calls will be performed.
    /// - Returns: The API instance and completes inmediately.
    internal init(api: API) {
        self.init { [weak api] (input, _) in
            guard let api = api else {
                return input.send(error: .sessionExpired())
            }
            
            input.send(value: (api, ()))
            input.sendCompleted()
        }
    }
}

extension SignalProducer where Error==API.Error {
    /// Initializes a `SignalProducer` that checks (when started) whether the passed API session has expired. It will also execute the `validating` closure and pass those values to the following step.
    /// - attention: This function makes a weak bond with the receiving API instance. When the `SignalProducer` is started, the bond will be tested and if the instance is `nil`, the `SignalProducer` will generate an error event.
    /// - parameter api: The API session where API calls will be performed.
    /// - parameter validating: Closure validating some values that will pass with the signal event to the following step.
    internal init<T>(api: API, validating: @escaping API.Request.Generator.Validation<T>) where Value==API.Request.WrapperValid<T> {
        self.init { [weak api] (input, _) in
            guard let api = api else {
                return input.send(error: .sessionExpired())
            }
            
            let values: T
            do {
                values = try validating(api)
            } catch let error as API.Error {
                return input.send(error: error)
            } catch let underlyingError {
                let error: API.Error = .invalidRequest("The request validation failed.", underlying: underlyingError, suggestion: API.Error.Suggestion.readDocumentation)
                return input.send(error: error)
            }
            
            input.send(value: (api, values))
            input.sendCompleted()
        }
    }
    
    /// Transforms every value from `self` into requests as specified in the closure given as argument.
    /// - parameter requestGenerator: The callback actually creating the `URLRequest`.
    /// - returns: New `SignalProducer` returning the request and the API instance.
    /// - seealso: URLRequest
    internal func request<T>(_ requestGenerator: @escaping API.Request.Generator.Request<T>) -> SignalProducer<API.Request.Wrapper,API.Error> where Value==API.Request.WrapperValid<T> {
        return self.attemptMap { (validated) -> Result<API.Request.Wrapper,API.Error> in
            let request: URLRequest
            do {
                request = try requestGenerator(validated.api, validated.values)
            } catch let error as API.Error {
                return .failure(error)
            } catch let underlyingError {
                let error: API.Error = .invalidRequest("The URL request couldn't be created.", underlying: underlyingError, suggestion: API.Error.Suggestion.readDocumentation)
                return .failure(error)
            }
            
            return .success( (validated.api, request) )
        }
    }
    
    /// Transforms every value from `self` into requests with the properties specified as parameters.
    /// - note: This is purely a convenience function, for requests that fall (even slightly) outside the given parameters, the other `request(_:)` function shall be used.
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
                             body bodyGenerator: API.Request.Generator.Body<T>? = nil) -> SignalProducer<API.Request.Wrapper,API.Error>  where Value==API.Request.WrapperValid<T> {
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
                } catch let underlyingError {
                    let error: API.Error = .invalidRequest("The URL request queries couldn't be formed.", underlying: underlyingError, suggestion: API.Error.Suggestion.readDocumentation)
                    return .failure(error)
                }
                
                if !queries.isEmpty {
                    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
                        let error: API.Error = .invalidRequest(#""\#(method.rawValue) \#(url)" URL cannot be transmuted into "URLComponents"."#, suggestion: API.Error.Suggestion.bug)
                        return .failure(error)
                    }
                    
                    components.queryItems = queries
                    guard let requestURL = components.url else {
                        let representation = queries.map { "\($0.name): \($0.value ?? "")" }.joined(separator: ", ")
                        let error: API.Error = .invalidRequest(#"An error was encountered when appending the URL queries "[\#(representation)]" to "\#(method.rawValue) \#(url)" URL."#, suggestion: API.Error.Suggestion.readDocumentation)
                        return .failure(error)
                    }
                    url = requestURL
                }
            }
            
            // Generate the result URLRequest.
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue
            
            let credentials: API.Credentials?
            if usingCredentials {
                if let storedCredentials = validated.api.session.credentials {
                    credentials = storedCredentials
                } else {
                    let error: API.Error = .invalidRequest(API.Error.Message.noCredentials, request: request, suggestion: API.Error.Suggestion.logIn)
                    return .failure(error)
                }
            } else {
                credentials = nil
            }
            
            do {
                request.addHeaders(version: version, credentials: credentials, try headerGenerator?(validated.api, validated.values))
            } catch let error as API.Error {
                return .failure(error)
            } catch let error {
                let error: API.Error = .invalidRequest("The request header couldn't be created.", request: request, underlying: error, suggestion: API.Error.Suggestion.readDocumentation)
                return .failure(error)
            }
            
            if let bodyGenerator = bodyGenerator {
                do {
                    let body = try bodyGenerator(validated.api, validated.values)
                    request.addValue(body.contentType.rawValue, forHTTPHeaderField: API.HTTP.Header.Key.requestType.rawValue)
                    request.httpBody = body.data
                } catch let error as API.Error {
                    return .failure(error)
                } catch let error {
                    let error: API.Error = .invalidRequest("The request body couldn't be created.", request: request, underlying: error, suggestion: API.Error.Suggestion.readDocumentation)
                    return .failure(error)
                }
            }
            return .success( (validated.api, request) )
        }
    }
}

extension SignalProducer where Value==API.Request.Wrapper, Error==API.Error {
    /// Executes for each value of `self`  the passed request on the passed API instance, returning the endpoint result.
    ///
    /// This `SignalProducer` will complete when the previous stage has completed and the current stage has also completed.
    /// - parameter type: The HTTP content type expected as a result.
    /// - returns: A new `SignalProducer` with the response of the executed enpoint.
    internal func send(expecting type: API.HTTP.Header.Value.ContentType? = nil) -> SignalProducer<API.Response.Wrapper,API.Error> {
        return self.remake { (value, generator, lifetime) in
            var request = value.request
            var detacher: CompositeDisposable? = nil
            
            if let contentType = type {
                request.addHeaders([.responseType: contentType.rawValue])
            }
            
            let task = value.api.channel.dataTask(with: request) { (data, response, error) in
                // Triggering `detacher` removes the observers from the API instance and signal lifetimes.
                detacher?.dispose()
                
                if let error = error {
                    let error: API.Error = .callFailed(message: "The HTTP request call failed.", request: request, response: response as? HTTPURLResponse, data: data, underlying: error, suggestion: "The server must be reachable before performing this request. Try again when the connection is established.")
                    return generator.send(error: error)
                }
                
                guard let header = response as? HTTPURLResponse else {
                    var error: API.Error = .callFailed(message: #"The response was not of HTTPURLResponse type."#, request: request, response: nil, data: data, underlying: error, suggestion: API.Error.Suggestion.bug)
                    if let httpResponse = response { error.context.append(("Received response", httpResponse)) }
                    return generator.send(error: error)
                }
                
                generator.send(value: (request,header,data))
                generator.sendCompleted()
            }
            
            // The `detacher` holds the `Disposable`s to eliminate the lifetimes observation.
            // When `detacher` is triggered/disposed, the observers are removed from the lifetimes.
            detacher = .init([value.api.lifetime, lifetime].compactMap {
                // The API and signal lifetimes are observed and in case of death, the download task is cancelled and an interruption is sent.
                $0.observeEnded {
                    generator.sendInterrupted()
                    task.cancel()
                }
            })
            
            task.resume()
        }
    }
    
    /// Similar than `send(expecting:)`, this method executes one (or many) requests on the passed API instance.
    ///
    /// The initial request is received as a value and is evaluated on the `intermediateRequest` closure. If the closure returns a `URLRequest`, that endpoint will be performed. If the closure returns `nil`, the signal producer will complete.
    /// - parameter intermediateRequest: All data needed to compile a request for the next page. If `nil` is returned, the request won't be performed and the signal will complete. On the other hand, if an error is thrown (which will be forced cast to `API.Error`), it will be forwarded as a failure event.
    /// - parameter endpoint: A paginated request response. The values/errors will be forwarded to the returned producer.
    /// - returns: A `SignalProducer` returning the values from `endpoint` as soon as they arrive. Only when `nil` is returned on the `request` closure, will the returned producer complete.
    internal func paginate<M,R>(request intermediateRequest: @escaping API.Request.Generator.RequestPage<M>, endpoint: @escaping API.Request.Generator.SignalPage<M,R>) -> SignalProducer<R,Error> {
        return self.remake { (value, generator, lifetime) in
            /// Recursive closure fed with the latest endpoint call (or `nil`) at the very beginning.
            var iterator: ( (_ previous: API.Request.WrapperPage<M>?) -> Void )! = nil
            /// Disposable used to detached the current page download task from the resulting signal's lifetime.
            var detacher: Disposable? = nil
            
            iterator = { [weak api = value.api, initialRequest = value.request] (previousRequest) in
                detacher?.dispose()
                
                guard let api = api else {
                    var error: API.Error = .sessionExpired()
                    error.request = initialRequest
                    if let previous = previousRequest {
                        error.context.append(("Last successfully executed paginated request", previous.request))
                    }
                    return generator.send(error: error)
                }
                
                let paginatedRequest: URLRequest?
                do {
                    paginatedRequest = try intermediateRequest(api, initialRequest, previousRequest)
                } catch let error as API.Error {
                    return generator.send(error: error)
                } catch let error {
                    var error: API.Error = .invalidRequest("The paginated request couldn't be created.", request: initialRequest, underlying: error, suggestion: API.Error.Suggestion.bug)
                    if let previous = previousRequest {
                        error.context.append(("Last successfully executed paginated request", previous.request))
                    }
                    return generator.send(error: error)
                }
                
                guard let nextRequest = paginatedRequest else {
                    return generator.sendCompleted()
                }
                
                detacher = lifetime += endpoint(.init(value: (api, nextRequest))).start {
                    switch $0 {
                    case .value((let meta, let value)):
                        generator.send(value: value)
                        return iterator((nextRequest, meta))
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

extension SignalProducer where Value==API.Response.Wrapper, Error==API.Error {
    /// Checks all the response headers from `self`'s values for status codes contained within the given parameters.
    /// - parameter statusCodes: All supported status codes.
    internal func validate<S>(statusCodes: S) -> SignalProducer<Value,Error> where S: Sequence, S.Element==Int {
        return self.attemptMap { (request, header, data) -> Result<Value,API.Error> in
            guard statusCodes.contains(header.statusCode) else {
                let message = #"The URL response code "\#(header.statusCode)" was received, when only \#(statusCodes) codes were expected."#
                let error: API.Error = .invalidResponse(message: message, request: request, response: header, data: data, suggestion: API.Error.Suggestion.reviewError)
                return .failure(error)
            }
            
            return .success((request,header,data))
        }
    }
    
    /// Checks all the response headers from `self`'s values for status codes contained within the given parameters.
    /// - parameter statusCodes: All supported status codes.
    internal func validate(statusCodes: Int...) -> SignalProducer<Value,Error> {
        return self.validate(statusCodes: statusCodes)
    }
    
    /// Checks that the returned response has a non-empty data body. Optionally, it can check for status codes (similarly to `validate(statusCodes:)`.
    /// - parameter statusCode: If not `nil`, the array indicates all *viable*/supported status codes.
    internal func validateLadenData<S>(statusCodes: S? = nil) -> SignalProducer<API.Response.WrapperData,Error> where S: Sequence, S.Element==Int {
        return self.attemptMap { (request, header, data) -> Result<API.Response.WrapperData,API.Error> in
            if let codes = statusCodes, !codes.contains(header.statusCode) {
                let message = #"The URL response code "\#(header.statusCode)" was received, when only \#(codes) codes were expected."#
                let error: API.Error = .invalidResponse(message: message, request: request, response: header, data: data, suggestion: API.Error.Suggestion.reviewError)
                return .failure(error)
            }
            
            guard let data = data else {
                let error: API.Error = .invalidResponse(message: "Response was expected to contained a body, but no data was found.", request: request, response: header, suggestion: API.Error.Suggestion.reviewError)
                return .failure(error)
            }
            
            return .success((request, header, data))
        }
    }
    
    /// Checks that the returned response has a non-empty data body. Optionally, it can check for status codes (similarly to `validate(statusCodes:)`.
    /// - parameter statusCode: If not `nil`, the array indicates all *viable*/supported status codes.
    internal func validateLadenData(statusCodes: Int...) -> SignalProducer<API.Response.WrapperData,Error> {
        return self.validateLadenData(statusCodes: statusCodes)
    }
}

extension SignalProducer where Value==API.Response.WrapperData, Error==API.Error {
    /// Decodes the JSON payload with a given `JSONDecoder`.
    /// - parameter decoderGenerator: Callback receiving the url request and HTTP header. It must return the JSON decoder to actually decode the data.
    /// - attention: The JSON decoder used (whether the defaul or a provided one) will get the response header (`HTTPURLResponse`) attached to the decoder's `userInfo` (key `API.JSON.DecoderKey.responseHeader`).
    internal func decodeJSON<T:Decodable>(with decoderGenerator: API.Request.Generator.Decoder? = nil) -> SignalProducer<T,API.Error> {
        return self.attemptMap { (request, header, data) -> Result<T,API.Error> in
            do {
                let decoder: JSONDecoder = try decoderGenerator?(request, header) ?? JSONDecoder()
                decoder.userInfo[API.JSON.DecoderKey.responseHeader] = header
                let result = try decoder.decode(T.self, from: data)
                return .success(result)
            } catch var error as API.Error {
                if case .none = error.request { error.request = request }
                if case .none = error.response { error.response = header }
                if case .none = error.responseData { error.responseData = data }
                return .failure(error)
            } catch let underlyingError {
                let message =  #"The response body could not be decoded as the expected type: "\#(T.self)"."#
                let suggestion = "Review the underlying error and try to figure out the issue."
                let error: API.Error = .invalidResponse(message: message, request: request, response: header, data: data, underlying: underlyingError, suggestion: suggestion)
                return .failure(error)
            }
        }
    }
}
