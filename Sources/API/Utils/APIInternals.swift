import Foundation

// MARK: - Request types

extension API.Request {
    /// Wrapper around a `URLRequest` and the API instance that will (most probably) execute such request.
    /// - returns: A `URLRequest` and an `API` instance.
    internal typealias Wrapper = (api: API, request: URLRequest)
    /// Request values that have been verified/validated.
    internal typealias Values<T> = (api: API, values: T)
    
    /// List of typealias representing closures which generate a specific data type.
    internal enum Generator {
        /// Closure receiving a valid API session and returning validated values.
        /// - parameter api: The API instance from where credentials an other temporal priviledge information is being retrieved.
        /// - returns: The validated values.
        typealias Validation<T> = (_ api: API) throws -> T
        /// Closure which returns a newly created `URLRequest` and provides with it an API instance.
        /// - parameter api: The API instance from where credentials an other temporal priviledge information is being retrieved.
        /// - parameter values: Values that have been validated in a previous step.
        /// - returns: A newly created `URLRequest`.
        typealias Request<T> = (_ api: API, _ values: T) throws -> URLRequest
        /// Closure which returns a bunch of query items to be used in a `URLRequest`.
        /// - parameter api: The API instance from where credentials an other temporal priviledge information is being retrieved.
        /// - parameter values: Values that have been validated in a previous step.
        /// - returns: Array of `URLQueryItem`s to be added to a `URLRequest`.
        typealias Query<T> = (_ api: API, _ values: T) throws -> [URLQueryItem]
        /// Closure which returns a bunch of header key-values to be used in a `URLRequest`.
        /// - parameter api: The API instance from where credentials an other temporal priviledge information is being retrieved.
        /// - parameter values: Values that have been validated in a previous step.
        /// - returns: Key-value pairs to be added to a `URLRequest`.
        typealias Header<T> = (_ api: API, _ values: T) throws -> [API.HTTP.Header.Key:String]
        /// Closure which returns a body to be appended to a `URLRequest`.
        /// - parameter api: The API instance from where credentials an other temporal priviledge information is being retrieved.
        /// - parameter values: Values that have been validated in a previous step.
        /// - returns: Tuple containing information about what type of body has been compiled and its data.
        typealias Body<T>  = (_ api: API, _ values: T) throws -> (contentType: API.HTTP.Header.Value.ContentType, data: Data)
        /// Closure which given a request and its actual response, generates a JSON decoder (typically to decode the responses payload).
        /// - parameter request: The URL request that returned the `response`.
        /// - parameter response: The HTTP response received from the execution of `request`.
        /// - returns: A JSON decoder (to typically decode the response's payload).
        typealias Decoder = (_ request: URLRequest, _ response: HTTPURLResponse) throws -> JSONDecoder
    }
}

// MARK: - Response Types

extension API.Response {
    /// Wrapper around a `URLRequest` and the received `HTTPURLResponse` and optional data payload.
    internal typealias Wrapper = (request: URLRequest, header: HTTPURLResponse, data: Data?)
    /// Wrapper around a `URLRequest` and the received `HTTPURLResponse` and a data payload.
    internal typealias DataWrapper = (request: URLRequest, header: HTTPURLResponse, data: Data)
}

// MARK: - Internal Types

extension API {
    /// Namespace for all JSON related constants (pertaining the API).
    internal enum JSON {
        /// Namesapce for JSON decoding keys.
        enum DecoderKey {
            /// Key for JSON decoders under which the URL response will be stored.
            static let responseHeader = CodingUserInfoKey(rawValue: "urlResponse")!
            /// Key for JSON decoders under which the response date is stored.
            static let responseDate = CodingUserInfoKey(rawValue: "urlResponseDate")!
            /// Key for JSON decoders under which a date formatter will be stored.
            static let dateFormatter = CodingUserInfoKey(rawValue: "dateFormatter")!
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
