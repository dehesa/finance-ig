import Combine
import Foundation

extension API {
    /// Domain namespace retaining anything related to API requests.
    public enum Request {}

    /// Namespace for all JSON related constants (pertaining the API).
    internal enum JSON {
        /// Namesapce for JSON decoding keys.
        enum DecoderKey {
            /// Key for JSON decoders under which the URL response (`HTTPURLResponse`' will be stored.
            static let responseHeader = CodingUserInfoKey(rawValue: "IG_APIResponseHeader").unsafelyUnwrapped
            /// Key for JSON decoders under which the URL response date (`Date`) will be stored.
            static let responseDate = CodingUserInfoKey(rawValue: "IG_APIResponseDate").unsafelyUnwrapped
            /// Key for JSON decoders under which the pre-computed values will be stored.
            static let computedValues = CodingUserInfoKey(rawValue: "IG_APIComputedValues").unsafelyUnwrapped
        }
        /// Specifies a `JSONDecoder` to use in further operations.
        enum Decoder<T> {
            /// The default `JSONDecoder` that has attached as `userInfo` any of the indicated associated values.
            case `default`(values: Bool = false, response: Bool = false, date: Bool = false)
            /// A custom `JSONDecoder` generated through the provided closure.
            case custom((_ request: URLRequest, _ response: HTTPURLResponse, _ values: T) throws -> JSONDecoder)
            /// A custom already-generated `JSONDecoder`.
            case predefined(JSONDecoder)
            
            /// Factory function creating a `JSONDecoder` from the receiving enum value.
            func makeDecoder(request: URLRequest, response: HTTPURLResponse, values: T) throws -> JSONDecoder {
                switch self {
                case .default(let includeValues, let includeResponse, let includeDate):
                    let decoder = JSONDecoder()
                    if includeResponse {
                        decoder.userInfo[API.JSON.DecoderKey.responseHeader] = response
                    }
                    if includeValues {
                        decoder.userInfo[API.JSON.DecoderKey.computedValues] = values
                    }
                    if includeDate {
                        guard let dateString = response.allHeaderFields[API.HTTP.Header.Key.date.rawValue] as? String,
                              let date = DateFormatter.humanReadableLong.date(from: dateString) else {
                            throw IG.Error(.api(.invalidResponse), "The response date couldn't be extracted from the response header.", help: "A unexpected error was encountered. Please contact the repository maintainer and attach this debug print.")
                        }
                        decoder.userInfo[API.JSON.DecoderKey.responseDate] = date
                    }
                    return decoder
                case .custom(let closure):
                    return try closure(request, response, values)
                case .predefined(let decoder):
                    return decoder
                }
            }
        }
    }
    
    /// HTTP related constants.
    internal enum HTTP {
        /// The HTTP method supported by this API
        /// - seealso: [w3.org website specifying the RFC2616 protocol](http://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html)
        enum Method: Hashable, CustomStringConvertible {
            /// POST method ask the resource at the given URI to do something with the provided entity. Usually, it creates a new entity.
            case post
            /// GET method is used to retrieve information.
            case get
            /// PUT method stores an entity at a URI. It is used to create a new entity or update an existing one.
            case put
            /// DELETE method request a resource to be removed.
            case delete
            
            var description: String {
                switch self {
                case .post: return "POST"
                case .get: return "GET"
                case .put: return "PUT"
                case .delete: return "DELETE"
                }
            }
        }
        
        /// HTTP header constants used by IG endpoints.
        enum Header {
            /// HTTP header keys used throughout IG endpoints.
            enum Key: String {
                /// Header key pointing to an IG account identifier.
                case account = "IG-ACCOUNT-ID"
                /// Header key pointing to an API key identifying an application/developer.
                case apiKey = "X-IG-API-KEY"
                /// OAuth header key.
                case authorization = "Authorization"
                /// Certificate header key.
                case clientSessionToken = "CST"
                /// Header key pointing at the date of package generation.
                case date = "Date"
                /// The platform specific request identifier.
                case requestId = "X-REQUEST-ID"
                /// They type of content in the package.
                case requestType = "Content-Type"
                /// The type of content is expected in the response package.
                case responseType = "Accept"
                /// Platform specific security key.
                case securityToken = "X-SECURITY-TOKEN"
                /// Platform specific versioning system for API endpoints.
                case version = "Version"
                /// Specifically used in the platform to change the type of HTTP method.
                case _method = "_method"
                
                /// Implementation-specific field.
                case pragma = "Pragma"
                /// Used to specify directives that must be obeyed by all caching mechanisms along the request-response chain.
                case cacheControl = "Cache-Control"
                
            }
            
            /// HTTP header values used throughout IG endpoints.
            enum Value {
                /// The type of content types supported by this API
                enum ContentType: CustomStringConvertible {
                    /// A JSON content type is expected.
                    case json
                    
                    var description: String {
                        switch self {
                        case .json: return "application/json; charset=UTF-8"
                        }
                    }
                }
            }
        }
    }
}
