import ReactiveSwift
import Foundation

extension IG.API.Request.Accounts {
    
    // MARK:  GET /accounts
    
    /// Returns a list of accounts belonging to the logged-in client.
    public func getAll() -> SignalProducer<[IG.API.Account],IG.API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "accounts", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
            .map { (w: Self.WrapperList) in w.accounts }
    }
    
    // MARK:  GET /accounts/preferences
    
    /// Returns the targeted account preferences.
    public func preferences() -> SignalProducer<IG.API.Account.Preferences,IG.API.Error> {
        return SignalProducer(api: self.api)
            .request(.get, "accounts/preferences", version: 1, credentials: true)
            .send(expecting: .json)
            .validateLadenData(statusCodes: 200)
            .decodeJSON()
    }

    // MARK:  PUT /accounts/preferences
    
    /// Updates the account preferences.
    /// - parameter trailingStops: Enable/Disable trailing stops in the current account.
    /// - returns: `SignalProducer` indicating the success of the operation.
    public func updatePreferences(trailingStops: Bool) -> SignalProducer<Void,IG.API.Error> {
        return SignalProducer(api: self.api) { _ -> Self.PayloadPreferences in
                return .init(trailingStopsEnabled: trailingStops)
            }.request(.put, "accounts/preferences", version: 1, credentials: true, body: { (_, payload) in
                return (.json, try JSONEncoder().encode(payload))
            }).send(expecting: .json)
            .validate(statusCodes: 200)
            .map { _ in return }
    }
}

// MARK: - Supporting Entities

extension IG.API.Request {
    /// Contains all functionality related to user accounts.
    public struct Accounts {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        fileprivate unowned let api: IG.API
        
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoints.
        init(api: IG.API) {
            self.api = api
        }
    }
}

// MARK: Request Entities

extension IG.API.Request.Accounts {
    private struct PayloadPreferences: Encodable {
        let trailingStopsEnabled: Bool
    }
}

// MARK: Response Entities

extension IG.API.Request.Accounts {
    private struct WrapperList: Decodable {
        let accounts: [IG.API.Account]
    }
}
