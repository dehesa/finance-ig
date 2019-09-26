extension SignalProducer where Value==IG.API.Request.Wrapper, Error==IG.API.Error {
    /// Executes for each value of `self`  the passed request on the passed IG.API instance, returning the endpoint result.
    ///
    /// This `SignalProducer` will complete when the previous stage has completed and the current stage has also completed.
    /// - parameter type: The HTTP content type expected as a result.
    /// - returns: A new `SignalProducer` with the response of the executed enpoint.
    internal func send(expecting type: IG.API.HTTP.Header.Value.ContentType? = nil) -> SignalProducer<IG.API.Response.Wrapper,Self.Error> {
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
                    let error: Self.Error = .callFailed(message: "The HTTP request call failed", request: request, response: response as? HTTPURLResponse, data: data, underlying: error, suggestion: "The server must be reachable before performing this request. Try again when the connection is established")
                    return generator.send(error: error)
                }
                
                guard let header = response as? HTTPURLResponse else {
                    var error: Self.Error = .callFailed(message: #"The response was not of HTTPURLResponse type"#, request: request, response: nil, data: data, underlying: error, suggestion: Self.Error.Suggestion.fileBug)
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
    internal func paginate<M,R>(request intermediateRequest: @escaping IG.API.Request.Generator.RequestPage<M>, endpoint: @escaping IG.API.Request.Generator.SignalPage<M,R>) -> SignalProducer<R,Error> {
        return self.remake { (value, generator, lifetime) in
            /// Recursive closure fed with the latest endpoint call (or `nil`) at the very beginning.
            var iterator: ( (_ previous: IG.API.Request.WrapperPage<M>?) -> Void )! = nil
            /// Disposable used to detached the current page download task from the resulting signal's lifetime.
            var detacher: Disposable? = nil
            
            iterator = { [weak api = value.api, initialRequest = value.request] (previousRequest) in
                detacher?.dispose()
                
                guard let api = api else {
                    var error: Self.Error = .sessionExpired()
                    error.request = initialRequest
                    if let previous = previousRequest {
                        error.context.append(("Last successfully executed paginated request", previous.request))
                    }
                    return generator.send(error: error)
                }
                
                let paginatedRequest: URLRequest?
                do {
                    paginatedRequest = try intermediateRequest(api, initialRequest, previousRequest)
                } catch let error as Self.Error {
                    return generator.send(error: error)
                } catch let error {
                    var error: Self.Error = .invalidRequest("The paginated request couldn't be created", request: initialRequest, underlying: error, suggestion: Self.Error.Suggestion.fileBug)
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
