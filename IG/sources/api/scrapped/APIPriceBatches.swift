import Combine
import Foundation
import Decimals

extension API.Request.Scrapped {
    
    // MARK: GET /chart/snapshot
    
    /// Returns a market snapshot for the given epic.
    ///
    /// The information retrieved is used to form charts on the IG platform.
    /// - parameter epic: Instrument's epic (e.g. `CS.D.EURUSD.MINI.IP`).
    /// - parameter resolution: It defines the resolution of requested prices.
    /// - parameter numDataPoints: The number of data points to receive on the prices array result.
    /// - parameter rootURL: The URL used as the based for all scrapped endpoints.
    /// - parameter scrappedCredentials: The credentials used to called endpoints from the IG's website.
    public func getPriceSnapshot(epic: IG.Market.Epic, resolution: API.Price.Resolution, numDataPoints: Int, rootURL: URL = API.scrappedRootURL, scrappedCredentials: (cst: String, security: String)) -> AnyPublisher<API.PriceSnapshot,IG.Error> {
        self.api.publisher
            .makeScrappedRequest(.get, url: { (_, _) in
                let interval = resolution._components
                let subpath = "chart/snapshot/\(epic)/\(interval.number)/\(interval.identifier)/combined-cached/\(numDataPoints)"
                return rootURL.appendingPathComponent(subpath)
            }, queries: { _ in
                [.init(name: "format", value: "json"),
                .init(name: "locale", value: Locale.london.identifier),
                .init(name: "delay", value: "0")]
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
    
    // MARK: GET /chart/snapshot
    
    /// - warning: Be mindful of the amount of data being requested. There is a maximum for each interval that can be requested.
    /// - parameter epic: Instrument's epic (e.g. `CS.D.EURUSD.MINI.IP`).
    /// - parameter resolution: It defines the resolution of requested prices.
    /// - parameter from: The date from which to start the query.
    /// - parameter to: The date from which to end the query.
    /// - parameter scalingFactor: The factor to be applied to every single data point returned.
    /// - parameter rootURL: The URL used as the based for all scrapped endpoints.
    /// - parameter scrappedCredentials: The credentials used to called endpoints from the IG's website.
    /// - returns: Sorted array (from past to present) with `numDataPoints` price data points.
    public func getPrices(epic: IG.Market.Epic, resolution: API.Price.Resolution, from: Date, to: Date, scalingFactor: Decimal64, rootURL: URL = API.scrappedRootURL, scrappedCredentials: (cst: String, security: String)) -> AnyPublisher<[API.Price],IG.Error> {
        self.api.publisher { _ -> (from: DateComponents, to: DateComponents) in
                guard from <= to else { throw IG.Error._invalidDates(from: from, to: to) }
                let fromComponents = UTC.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: from)
                let toComponents = UTC.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: to)
                return (fromComponents, toComponents)
            }.makeScrappedRequest(.get, url: { (_, values) in
                let interval = resolution._components
                let (f, t) = values
                let subpath = "chart/snapshot/\(epic)/\(interval.number)/\(interval.identifier)/batch/start/\(f.year!)/\(f.month!)/\(f.day!)/\(f.hour!)/\(f.minute!)/\(f.second!)/\(min(f.nanosecond!, 999))/end/\(t.year!)/\(t.month!)/\(t.day!)/\(t.hour!)/\(t.minute!)/\(t.second!)/\(min(t.nanosecond!,999))"
                return rootURL.appendingPathComponent(subpath)
            }, queries: { _ in
                [.init(name: "format", value: "json"),
                 .init(name: "locale", value: Locale.london.identifier)]
            }, headers: { (_, _) in
                [.clientSessionToken: scrappedCredentials.cst,
                 .securityToken: scrappedCredentials.security,
                 .pragma: "no-cache",
                 .cacheControl: "no-cache"]
            }).send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .custom({ (_, _, _) in JSONDecoder().set { $0.userInfo[._scalingFactor] = scalingFactor } })) { (response: API.Market._ScrappedBatch, _) in
                response.prices
            }.mapError(errorCast)
            .eraseToAnyPublisher()
    }
}

// MARK: - Helpers

internal extension CodingUserInfoKey {
    /// Key for JSON decoders under which a scaling factor for price values will be stored.
    static var _scalingFactor: CodingUserInfoKey { CodingUserInfoKey(rawValue: "IG_APIScrappedScaling").unsafelyUnwrapped }
}

fileprivate extension API.Price.Resolution {
    /// The components identifying the receiving resolution.
    var _components: (number: Int, identifier: String) {
        switch self {
        case .second:   return (1, "SECOND")
        case .minute:   return (1, "MINUTE")
        case .minute2:  return (2, "MINUTE")
        case .minute3:  return (3, "MINUTE")
        case .minute5:  return (5, "MINUTE")
        case .minute10: return (10, "MINUTE")
        case .minute15: return (15, "MINUTE")
        case .minute30: return (30, "MINUTE")
        case .hour:     return (1, "HOUR")
        case .hour2:    return (2, "HOUR")
        case .hour3:    return (3, "HOUR")
        case .hour4:    return (4, "HOUR")
        case .day:      return (1, "DAY")
        case .week:     return (1, "WEEK")
        case .month:    return (1, "MONTH")
        }
    }
    
    /// The number of data points needed for a minute worth.
    func _numDataPoints(minutes: Int) -> Int {
        switch self {
        case .second:   return minutes * 60
        case .minute:   return minutes
        case .minute2:  return (minutes / 2) + 1
        case .minute3:  return (minutes / 3) + 1
        case .minute5:  return (minutes / 5) + 1
        case .minute10: return (minutes / 10) + 1
        case .minute15: return (minutes / 15) + 1
        case .minute30: return (minutes / 30) + 1
        case .hour:     return (minutes / 60) + 1
        case .hour2:    return (minutes / (60 * 2)) + 1
        case .hour3:    return (minutes / (60 * 3)) + 1
        case .hour4:    return (minutes / (60 * 4)) + 1
        case .day:      return (minutes / (60 * 24)) + 1
        case .week:     return (minutes / (60 * 24 * 7)) + 1
        case .month:    return (minutes / (60 * 24 * 30)) + 1
        }
    }
}

private extension IG.Error {
    /// Error raised when event dates are invalid.
    static func _invalidDates(from: Date, to: Date) -> Self {
        Self(.api(.invalidRequest), "The 'from' date must occur before the 'to' date", help: "Read the request documentation and be sure to follow all requirements.", info: ["From": from, "To": to])
    }
}
