@testable import IG
import ReactiveSwift
import XCTest

extension Test {
    /// Creates an API instance from the running test account.
    static func makeAPI(scheme: Self.Account.SupportedScheme = Self.account.api.scheme,
                        rootURL: URL = Self.account.api.rootURL,
                        credentials: API.Credentials?) -> IG.API {
        switch scheme {
        case .https:
            return .init(rootURL: rootURL, channel: URLSession(configuration: IG.API.defaultSessionConfigurations), credentials: credentials)
        case .file:
            return .init(rootURL: rootURL, channel: APIFileChannel(), credentials: credentials)
        }
    }           
}
