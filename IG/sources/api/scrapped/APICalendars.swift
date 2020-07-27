import Combine
import Foundation
import Decimals

extension API.Request {
    /// List of endpoints scrapped from the website.
    ///
    /// This endpoints require specific usage and won't work with the API key settings.
    @frozen public struct Scrapped {
        /// Pointer to the actual API instance in charge of calling the endpoint.
        @usableFromInline internal unowned let api: API
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoints.
        @usableFromInline internal init(api: API) { self.api = api }
    }
}

extension API.Request.Scrapped {
    
    // MARK: GET /chartscalendar/events
    
    /// Returns a list of events happening between the given dates in the economic calendar.
    /// - parameter epic: Instrument's epic (e.g. `CS.D.EURUSD.MINI.IP`).
    /// - parameter from: The date from which to start the query.
    /// - parameter to: The date from which to end the query.
    /// - returns: Publisher forwarding all user's applications.
    public func getEvents(epic: IG.Market.Epic, from: Date, to: Date, rootURL: URL = API.scrappedRootURL, scrappedCredentials: (cst: String, security: String)) -> AnyPublisher<[API.Calendar.Event],IG.Error> {
        self.api.publisher { _ throws -> (from: Int, to: Int) in
                guard from <= to else { throw IG.Error._invalidDates(from: from, to: to) }
                let fromInterval = Int(from.timeIntervalSince1970) * 1000
                let toInterval = Int(to.timeIntervalSince1970) * 1000
                return (fromInterval, toInterval)
            }.makeScrappedRequest(.get, url: {  (_, values) -> URL in
                let subpath = "chartscalendar/events/\(epic)/from/\(values.from)/to/\(values.to)/"
                return rootURL.appendingPathComponent(subpath)
            }, queries: { _ in
                [.init(name: "ssoToken", value: scrappedCredentials.security),
                 .init(name: "locale", value: Locale.london.identifier),
                 .init(name: "eventType", value: "ECONOMIC_CALENDAR")]
            }, headers: { (_, _) in
                [.clientSessionToken: scrappedCredentials.cst,
                 .securityToken: scrappedCredentials.security,
                 .pragma: "no-cache",
                 .cacheControl: "no-cache"]
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default())
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

private extension IG.Error {
    /// Error raised when event dates are invalid.
    static func _invalidDates(from: Date, to: Date) -> Self {
        Self(.api(.invalidRequest), "The 'from' date must occur before the 'to' date", help: "Read the request documentation and be sure to follow all requirements.", info: ["From": from, "To": to])
    }
}
