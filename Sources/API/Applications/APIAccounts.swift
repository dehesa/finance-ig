import Combine
import Foundation

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

extension IG.API.Request.Accounts {
    
    // MARK:  GET /accounts
    
    /// Returns a list of accounts belonging to the logged-in client.
    /// - returns: `Future` related type forwarding a list of user's accounts.
    public func getAll() -> AnyPublisher<[IG.API.Account],IG.API.Error> {
        self.api.publisher
            .makeRequest(.get, "accounts", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default()) { (w: Self.WrapperList, _) in
                w.accounts
            }.mapError(IG.API.Error.transform)
            .eraseToAnyPublisher()
    }
    
    // MARK:  GET /accounts/preferences
    
    /// Returns the targeted account preferences.
    /// - returns: `Future` related type forwarding the current account's pereferences.
    public func preferences() -> AnyPublisher<IG.API.Account.Preferences,IG.API.Error> {
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
    /// - returns: `Future` related type indicating the success of the operation with a successful complete.
    public func updatePreferences(trailingStops: Bool) -> AnyPublisher<Never,IG.API.Error> {
        self.api.publisher { (_) -> Self.PayloadPreferences in
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

extension IG.API.Request.Accounts {
    private struct PayloadPreferences: Encodable {
        let trailingStopsEnabled: Bool
    }
}

extension IG.API.Request.Accounts {
    private struct WrapperList: Decodable {
        let accounts: [IG.API.Account]
    }
}
