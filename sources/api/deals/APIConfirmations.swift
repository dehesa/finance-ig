import Combine

extension API.Request {
    /// List of endpoints related to API positions.
    @frozen public struct Deals {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        @usableFromInline internal unowned let api: API
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoint.
        @usableFromInline internal init(api: API) { self.api = api }
    }
}

extension API.Request.Deals {
    /// It is used to received a confirmation on a deal (whether position or working order)
    ///
    /// Trade confirmation is done in two phases:
    /// - **Acknowledgement**. A deal reference is returned via the `api.positions.create(...)` or `api.workingOrders.create(...)` endpoints when an order is placed.
    /// - **Confirmation**. A deal identifier is received by subscribing to the `streamer.confirmations.subscribe(...)` streaming messages (recommended), or by polling this endpoint.
    /// Most orders are usually executed within a few milliseconds but the confirmation may not be available immediately if there is a delay.
    /// - seealso: GET /confirms/{dealReference}
    /// - note: the confirmation is only available up to 1 minute via this endpoint.
    /// - parameter reference: Temporary targeted deal reference.
    public func getConfirmation(reference: IG.Deal.Reference) -> AnyPublisher<API.Confirmation,IG.Error> {
        self.api.publisher
            .makeRequest(.get, "confirms/\(reference)", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
}
