import Combine
import Foundation

extension IG.API {
    /// Publisher sending downstream the receiving `API` instance. If the instance has been deallocated when the chain is activated, a failure is sent downstream.
    /// - returns: A Combine `Future` sending an `API` instance and completing immediately once it is activated.
    internal var publisher: IG.API.Publishers.Instance<Void> {
        Future { [weak self] (promise) in
            if let self = self {
                promise(.success( (self,()) ))
            } else {
                promise(.failure( API.Error.sessionExpired() ))
            }
        }
    }
    
    /// Publisher sending downstream the receiving `API` instance and some computed values. If the instance has been deallocated or the values cannot be generated, the publisher fails.
    /// - parameter valuesGenerator: Closure generating the values to be send downstream along with the `API` instance.
    /// - returns: A Combine `Future` sending an `API` instance along with some computed values and completing immediately once it is activated.
    internal func publisher<T>(_ valuesGenerator: @escaping (_ api: IG.API) throws -> T) -> IG.API.Publishers.Instance<T> {
        Future { [weak self] (promise) in
            guard let self = self else { return promise(.failure(API.Error.sessionExpired())) }
            promise(.init { (self, try valuesGenerator(self)) })
        }
    }
}

extension Future where Failure==Swift.Error {
    /// Transforms the upstream `API` instance and computed values into a URL request with the properties specified as arguments.
    /// - parameter method: The HTTP method of the endpoint.
    /// - parameter relativeURL: The relative URL to be appended to the API instance root URL.
    /// - parameter version: The API endpoint version number (to be included in the HTTP header).
    /// - parameter usingCredentials: Whether the request shall include credential headers.
    /// - parameter queryGenerator: Optional array of queries to be attached to the request.
    /// - parameter headGenerator: Optional/Additional headers to be included in the request.
    /// - parameter bodyGenerator: Optional body generator to include in the request.
    /// - returns: A Combine `Future` sending an `API` instance, some computed values, and a valid URL request.
    internal func makeRequest<T>(_ method: IG.API.HTTP.Method, _ relativeURL: String, version: Int, credentials usingCredentials: Bool,
                                 queries queryGenerator: ((_ values: T) throws -> [URLQueryItem])? = nil,
                                 headers headGenerator:  ((_ values: T) throws -> [IG.API.HTTP.Header.Key:String])? = nil,
                                 body    bodyGenerator:  ((_ values: T) throws -> (contentType: IG.API.HTTP.Header.Value.ContentType, data: Data))? = nil) -> IG.API.Publishers.Request<T> where Output==IG.API.Publishers.Instance<T>.Output {
        self.tryMap { (api, values) in
            var request = URLRequest(url: api.rootURL.appendingPathComponent(relativeURL))
            request.httpMethod = method.rawValue
            
            do {
                if let queries = try queryGenerator?(values) {
                    try request.addQueries(queries)
                }

                let credentials = (!usingCredentials) ? nil : try api.session.credentials ?! IG.API.Error.invalidRequest(.noCredentials, request: request, suggestion: .logIn)
                request.addHeaders(version: version, credentials: credentials, try headGenerator?(values))

                if let body = try bodyGenerator?(values) {
                    request.addValue(body.contentType.rawValue, forHTTPHeaderField: IG.API.HTTP.Header.Key.requestType.rawValue)
                    request.httpBody = body.data
                }
            } catch var error as IG.API.Error {
                if case .none = error.request { error.request = request }
                throw error
            } catch let error {
                throw IG.API.Error.invalidRequest("The URL request couldn't be created", request: request, underlying: error, suggestion: .readDocs)
            }

            return (api, request, values)
        }
    }
}

extension Publishers.TryMap {
    /// Perform the request specified as upstream value on the `API`'s session passed along with it.
    ///
    /// The operator will also check that the network package received has the appropriate `HTTPURLResponse` header, is of the expected type (e.g. JSON) and it has the expected response status code (if any has been indicated).
    /// - parameter type: The HTTP content type expected as a result.
    /// - parameter statusCodes: If not `nil`, the sequence indicates all *viable*/supported status codes.
    /// - returns: A `Future` related type forwarding  downstream the endpoint request, response, received blob/data, and any pre-computed values.
    internal func send<S,T>(expecting type: IG.API.HTTP.Header.Value.ContentType? = nil, statusCodes: S? = nil) -> IG.API.Publishers.Call<T> where Upstream==IG.API.Publishers.Instance<T>, Output==IG.API.Publishers.Request<T>.Output, S:Sequence, S.Element==Int {
        self.flatMap(maxPublishers: .max(1)) { (api, request, values) in
            api.channel.dataTaskPublisher(for: request).tryMap { (data, response) in
                guard let httpResponse = response as? HTTPURLResponse else {
                    let message = #"The response was not of HTTPURLResponse type"#
                    throw IG.API.Error.callFailed(message: .init(message), request: request, response: nil, data: data, underlying: nil, suggestion: .fileBug)
                }
                
                if let expectedCodes = statusCodes, !expectedCodes.contains(httpResponse.statusCode) {
                    let message = #"The URL response code "\#(httpResponse.statusCode)" was received, when only \#(expectedCodes) codes were expected"#
                    throw IG.API.Error.invalidResponse(message: .init(message), request: request, response: httpResponse, data: data, underlying: nil, suggestion: .reviewError)
                }
                
                return (request, httpResponse, data, values)
            }.mapError {
                switch $0 {
                case var error as IG.API.Error:
                    if case .none = error.request { error.request = request }
                    return error
                case let error as URLError:
                    let message: IG.API.Error.Message = "An internal session error occurred while calling the HTTP endpoint"
                    return IG.API.Error.callFailed(message: message, request: request, response: nil, data: nil, underlying: error, suggestion: .reviewError)
                case let error:
                    let message: IG.API.Error.Message = "An unknown error occurred while calling the HTTP endpoint"
                    return IG.API.Error.callFailed(message: message, request: request, response: nil, data: nil, underlying: error, suggestion: .reviewError)
                }
            }
        }
    }
    
    /// Perform the request specified as upstream value on the `API`'s session passed along with it.
    ///
    /// The operator will also check that the network package received has the appropriate `HTTPURLResponse` header, is of the expected type (e.g. JSON) and it has the expected response status code (if any has been indicated).
    /// - parameter type: The HTTP content type expected as a result.
    /// - parameter codes: List of HTTP status codes expected (i.e. the endpoint call is considered successful).
    /// - returns: A `Future` related type forwarding  downstream the endpoint request, response, received blob/data, and any pre-computed values.
    internal func send<T>(expecting type: IG.API.HTTP.Header.Value.ContentType? = nil, statusCode codes: Int...) -> IG.API.Publishers.Call<T> where Upstream==IG.API.Publishers.Instance<T>, Output==IG.API.Publishers.Request<T>.Output {
        return self.send(expecting: type, statusCodes: codes)
    }
}

extension Publishers.FlatMap {
    /// Decodes the JSON payload with a given `JSONDecoder`.
    /// - parameter decoder: Enum indicating how the `JSONDecoder` is created/obtained.
    /// - returns: A `Future` related type forwarding the decoded network response.
    internal func decodeJSON<T,R:Decodable>(decoder: IG.API.JSON.Decoder<T>, result: R.Type = R.self) -> IG.API.Publishers.Decode<T,R> where Upstream==IG.API.Publishers.Request<T>, NewPublisher==Publishers.MapError<Publishers.TryMap<URLSession.DataTaskPublisher,(request:URLRequest,response:HTTPURLResponse,data:Data,values:T)>,Swift.Error> {
        self.tryMap { (request, response, data, values) -> R in
            var decodingStage = true
            do {
                let jsonDecoder = try decoder.makeDecoder(request: request, response: response, values: values); decodingStage.toggle()
                return try jsonDecoder.decode(R.self, from: data)
            } catch var error as IG.API.Error {
                if case .none = error.request { error.request = request }
                if case .none = error.response { error.response = response }
                if case .none = error.responseData { error.responseData = data }
                throw error
            } catch let error {
                let msg: String
                switch decodingStage {
                case true:  msg = "A JSON decoder couldn't be created"
                case false: msg = #"The response body could not be decoded as the expected type: "\#(R.self)""#
                }
                throw IG.API.Error.invalidResponse(message: .init(msg), request: request, response: response, data: data, underlying: error, suggestion: .reviewError)
            }
        }
    }
    
    /// Decodes the JSON payload with a given `JSONDecoder` and then performs a transformation to the result.
    /// - parameter decoder: Enum indicating how the `JSONDecoder` is created/obtained.
    /// - parameter transform: Transformation to be applied to the result of the JSON decoding.
    /// - returns: A `Future` related type forwarding the result of decoding network response and performing a transformation on it.
    internal func decodeJSON<T,R:Decodable,W>(decoder: IG.API.JSON.Decoder<T>, transform: @escaping (_ decoded: R, _ call: (request: URLRequest, response: HTTPURLResponse)) throws -> W) -> IG.API.Publishers.Decode<T,W> where Upstream==IG.API.Publishers.Request<T>, NewPublisher==Publishers.MapError<Publishers.TryMap<URLSession.DataTaskPublisher,(request:URLRequest,response:HTTPURLResponse,data:Data,values:T)>,Swift.Error> {
        self.tryMap { (request, response, data, values) -> W in
            var stage: Int = 0
            do {
                let jsonDecoder = try decoder.makeDecoder(request: request, response: response, values: values); stage += 1
                let payload = try jsonDecoder.decode(R.self, from: data); stage += 2
                return try transform(payload, (request, response))
            } catch var error as IG.API.Error {
                if case .none = error.request { error.request = request }
                if case .none = error.response { error.response = response }
                if case .none = error.responseData { error.responseData = data }
                throw error
            } catch let error {
                let msg: String
                switch stage {
                case 0: msg = #"A JSON decoder couldn't be created"#
                case 1: msg = #"The response body could not be decoded as the expected type: "\#(R.self)""#
                default: msg = #"The response body was decoded successfully from JSON, but it couldn't be transformed into the type: "\#(W.self)""#
                }
                throw IG.API.Error.invalidResponse(message: .init(msg), request: request, response: response, data: data, underlying: error, suggestion: .reviewError)
            }
        }
    }
}
