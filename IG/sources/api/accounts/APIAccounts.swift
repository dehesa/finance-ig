import Combine
import Foundation

extension API.Request {
    /// List of endpoints related to user accounts.
    @frozen public struct Accounts {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        @usableFromInline internal unowned let api: API
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoints.
        @usableFromInline internal init(api: API) { self.api = api }
    }
}

extension API.Request.Accounts {
    
    // MARK:  GET /accounts
    
    /// Returns a list of accounts belonging to the logged-in client.
    /// - returns: Publisher forwarding a list of user's accounts.
    public func getAll() -> AnyPublisher<[API.Account],IG.Error> {
        self.api.publisher
            .makeRequest(.get, "accounts", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: _WrapperList, _) in
                w.accounts
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    // MARK:  GET /accounts/preferences
    
    /// Returns the targeted account preferences.
    /// - returns: Publisher forwarding the current account's pereferences.
    public func getPreferences() -> AnyPublisher<API.Account.Preferences,IG.Error> {
        self.api.publisher
            .makeRequest(.get, "accounts/preferences", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }

    // MARK:  PUT /accounts/preferences
    
    /// Updates the account preferences.
    /// - parameter trailingStops: Enable/Disable trailing stops in the current account.
    /// - returns: Publisher indicating the success of the operation.
    public func updatePreferences(trailingStops: Bool) -> AnyPublisher<Never,IG.Error> {
        self.api.publisher { _ -> _PayloadPreferences in
                .init(trailingStopsEnabled: trailingStops)
            }.makeRequest(.put, "accounts/preferences", version: 1, credentials: true, body: { (payload) in
                (.json, try JSONEncoder().encode(payload))
            }).send(expecting: .json, statusCode: 200)
            .ignoreOutput()
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

// MARK: - Request Entities

private extension API.Request.Accounts {
    struct _PayloadPreferences: Encodable {
        let trailingStopsEnabled: Bool
    }
}

// MARK: Response Entities

private extension API.Request.Accounts {
    struct _WrapperList: Decodable {
        let accounts: [API.Account]
    }
}
