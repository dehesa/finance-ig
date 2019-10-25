import Combine
import Foundation

extension IG.API {
    /// Domain namespace retaining anything related to API requests.
    public enum Request {}
    
    /// Type erased `Combine.Future` where a single value and a completion or a failure will be sent.
    /// This behavior is guaranteed when you see this type.
    public typealias DiscretePublisher<T> = Combine.AnyPublisher<T,IG.API.Error>
    /// Publisher that can send zero, one, or many values followed by a successful completion.
    ///
    /// This type is typically semantically used for paginated requests.
    public typealias ContinuousPublisher<T> = Combine.AnyPublisher<T,IG.API.Error>
}

extension IG.API {
    /// Publisher's output types.
    internal enum Output {
        /// API pipeline's first stage variables: the API instance to use and some computed values (or `Void`).
        internal typealias Instance<T> = (api: IG.API, values: T)
        /// API pipeline's second stage variables: the API instance to use, the URL request to perform, and some computed values (or `Void`).
        internal typealias Request<T> = (api: IG.API, request:URLRequest, values: T)
        /// API pipeline's third stage variables: the request that has been performed, the response and payload received, and some computed values (or `Void`).
        internal typealias Call<T> = (request: URLRequest, response: HTTPURLResponse, data: Data, values: T)
        /// Previous paginated page values: the previous successful request and its metadata.
        internal typealias PreviousPage<M> = (request: URLRequest, metadata: M)
    }
}

// MARK: - Constant

extension IG.API {
    /// Namespace for all JSON related constants (pertaining the API).
    internal enum JSON {
        /// Namesapce for JSON decoding keys.
        enum DecoderKey {
            /// Key for JSON decoders under which the URL response (`HTTPURLResponse`' will be stored.
            static let responseHeader = CodingUserInfoKey(rawValue: "IG_APIResponseHeader")!
            /// Key for JSON decoders under which the URL response date (`Date`) will be stored.
            static let responseDate = CodingUserInfoKey(rawValue: "IG_APIResponseDate")!
            /// Key for JSON decoders under which the pre-computed values will be stored.
            static let computedValues = CodingUserInfoKey(rawValue: "IG_APIComputedValues")!
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
                        decoder.userInfo[IG.API.JSON.DecoderKey.responseHeader] = response
                    }
                    if includeValues {
                        decoder.userInfo[IG.API.JSON.DecoderKey.computedValues] = values
                    }
                    if includeDate {
                        guard let dateString = response.allHeaderFields[IG.API.HTTP.Header.Key.date.rawValue] as? String,
                              let date = IG.API.Formatter.humanReadableLong.date(from: dateString) else {
                            let message = "The response date couldn't be extracted from the response header"
                            throw IG.API.Error.invalidResponse(message: .init(message), request: request, response: response, suggestion: .fileBug)
                        }
                        decoder.userInfo[IG.API.JSON.DecoderKey.responseDate] = date
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
        enum Method: String {
            /// POST method ask the resource at the given URI to do something with the provided entity. Usually, it creates a new entity.
            case post = "POST"
            /// GET method is used to retrieve information.
            case get = "GET"
            /// PUT method stores an entity at a URI. It is used to create a new entity or update an existing one.
            case put = "PUT"
            /// DELETE method request a resource to be removed.
            case delete = "DELETE"
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
                enum ContentType: String {
                    /// A JSON content type is expected.
                    case json = "application/json; charset=UTF-8"
                }
            }
        }
    }
}
