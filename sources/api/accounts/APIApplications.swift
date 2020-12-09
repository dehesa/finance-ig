import Combine
import Foundation

extension API.Request.Accounts {
    /// Returns a list of client-owned applications.
    /// - seealso: GET /operations/application
    /// - returns: Publisher forwarding all user's applications.
    public func getApplications() -> AnyPublisher<[API.Application],IG.Error> {
        self.api.publisher
            .makeRequest(.get, "operations/application", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }

    /// Alters the details of a given user application.
    /// - seealso: PUT /operations/application
    /// - parameter key: The API key of the application that will be modified. If `nil`, the application being modified is the one that the API instance has credentials for.
    /// - parameter status: The status to apply to the receiving application.
    /// - parameter allowance: `overall`: Per account request per minute allowance. `trading`: Per account trading request per minute allowance.
    /// - returns: Publisher forwarding the newly set targeted application values.
    public func updateApplication(key: API.Key? = nil, status: API.Application.Status, accountAllowance allowance: (overall: UInt, trading: UInt)) -> AnyPublisher<API.Application,IG.Error> {
        self.api.publisher { (api) throws -> _PayloadUpdate in
            let apiKey = try (key ?? api.channel.credentials?.key) ?> IG.Error._unfoundCredentials()
                return .init(key: apiKey, status: status, overallAccountRequests: allowance.overall, tradingAccountRequests: allowance.trading)
            }.makeRequest(.put, "operations/application", version: 1, credentials: true, body: { (payload) in
                return (.json, try JSONEncoder().encode(payload))
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

// MARK: - Request Entities

private extension API.Request.Accounts {
    /// Let the user updates one parameter of its application.
    struct _PayloadUpdate: Encodable {
        ///.API key to be added to the request.
        let key: API.Key
        /// Desired application status.
        let status: API.Application.Status
        /// Per account request per minute allowance.
        let overallAccountRequests: UInt
        /// Per account trading request per minute allowance.
        let tradingAccountRequests: UInt
        
        private enum CodingKeys: String, CodingKey {
            case key = "apiKey", status
            case overallAccountRequests = "allowanceAccountOverall"
            case tradingAccountRequests = "allowanceAccountTrading"
        }
    }
}

private extension IG.Error {
    /// Error raised when no API credentials were found.
    static func _unfoundCredentials() -> Self {
        Self(.api(.invalidRequest), "No credentials were found on the API instance", help: "Log in before calling this request")
    }
}
