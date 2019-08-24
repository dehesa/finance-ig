import ReactiveSwift
import Foundation

extension API {
    
    // MARK: - GET /confirms/{dealReference}
    
    /// It is used to received a confirmation on a deal (whether position or working order)
    ///
    /// Trade confirmation is done in two phases:
    /// - **Acknowledgement**. A deal reference is returned via the `api.positions.create(...)` or `api.workingOrders.create(...)` endpoints when an order is placed.
    /// - **Confirmation**. A deal identifier is received by subscribing to the `streamer.confirmations.subscribe(...)` streaming messages (recommended), or by polling this endpoint.
    /// Most orders are usually executed within a few milliseconds but the confirmation may not be available immediately if there is a delay.
    /// - note: the confirmation is only available up to 1 minute via this endpoint.
    /// - parameter reference: Temporary targeted deal reference.
    public func confirm(reference: IG.Deal.Reference) -> SignalProducer<IG.Confirmation,API.Error> {
        return SignalProducer(api: self)
            .request(.get, "confirms/\(reference.rawValue)", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
    }
}
