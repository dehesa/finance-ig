import Combine
import Foundation

extension IG.API.Request {
    /// List of endpoints related to user accounts.
    public struct Accounts {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        internal unowned let api: IG.API
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoints.
        init(api: IG.API) { self.api = api }
    }
}

extension IG.API.Request.Accounts {
    
    // MARK:  GET /accounts
    
    /// Returns a list of accounts belonging to the logged-in client.
    /// - returns: *Future* forwarding a list of user's accounts.
    public func getAll() -> AnyPublisher<[IG.API.Account],IG.API.Error> {
        self.api.publisher
            .makeRequest(.get, "accounts", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: _WrapperList, _) in
                w.accounts
            }.mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
    
    // MARK:  GET /accounts/preferences
    
    /// Returns the targeted account preferences.
    /// - returns: *Future* forwarding the current account's pereferences.
    public func getPreferences() -> AnyPublisher<IG.API.Account.Preferences,IG.API.Error> {
        self.api.publisher
            .makeRequest(.get, "accounts/preferences", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }

    // MARK:  PUT /accounts/preferences
    
    /// Updates the account preferences.
    /// - parameter trailingStops: Enable/Disable trailing stops in the current account.
    /// - returns: *Future* indicating the success of the operation.
    public func updatePreferences(trailingStops: Bool) -> AnyPublisher<Never,IG.API.Error> {
        self.api.publisher { _ -> _PayloadPreferences in
                .init(trailingStopsEnabled: trailingStops)
            }.makeRequest(.put, "accounts/preferences", version: 1, credentials: true, body: { (payload) in
                (.json, try JSONEncoder().encode(payload))
            }).send(expecting: .json, statusCode: 200)
            .ignoreOutput()
            .mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
}

// MARK: - Entities

private extension IG.API.Request.Accounts {
    struct _PayloadPreferences: Encodable {
        let trailingStopsEnabled: Bool
    }
}

private extension IG.API.Request.Accounts {
    struct _WrapperList: Decodable {
        let accounts: [IG.API.Account]
    }
}
