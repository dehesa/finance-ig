import Combine
import Foundation

extension IG.API {
    /// Domain namespace retaining anything related to API requests.
    public enum Request {}
//    /// Domain namespace retaining anything related to API responses.
//    public enum Response {}
    /// List of publishers supported by API instances.
    internal enum Publishers {}
}

extension IG.API.Publishers {
    /// `Future` forwarding an `API` instance and some computed values (to use further downstream).
    internal typealias Instance<T> = Future<(api:IG.API,values:T),Swift.Error>
    /// `Future` forwarding an `API` instance, some computed values (to use further downstream), and a valid `URLRequest`.
    internal typealias Request<T> = Publishers.TryMap<Instance<T>,(api:IG.API,request:URLRequest,values:T)>
    /// A `Future` related type forwarding downstream the endpoint request, response, received blob/data, and any pre-computed values.
    internal typealias Call<T> = Publishers.FlatMap<Publishers.MapError<Publishers.TryMap<URLSession.DataTaskPublisher,(request:URLRequest,response:HTTPURLResponse,data:Data,values:T)>,Swift.Error>,Request<T>>
    /// A `Future` related type forwarding downstream the decoded network response.
    internal typealias Decode<T,R> = Publishers.TryMap<Call<T>,R>
}

// MARK: - Constant Types

extension IG.API {
    /// Namespace for all JSON related constants (pertaining the API).
    internal enum JSON {
        /// Namesapce for JSON decoding keys.
        enum DecoderKey {
            /// Key for JSON decoders under which the URL response will be stored.
            static let request = CodingUserInfoKey(rawValue: "urlRequest")!
            /// Key for JSON decoders under which the URL response will be stored.
            static let responseHeader = CodingUserInfoKey(rawValue: "urlResponse")!
            /// Key for JSON decoders under which the URL response data will be stored.
            static let responseDate = CodingUserInfoKey(rawValue: "urlResponseDate")!
            /// Key for JSON decoders under which the pre-computed values will be stored.
            static let computedValues = CodingUserInfoKey(rawValue: "computedValues")!
            #warning("API: Delete this and include it as values")
            /// Key for JSON decoders under which a date formatter will be stored.
            static let dateFormatter = CodingUserInfoKey(rawValue: "APIDateFormatter")!
        }
        /// Specifies a `JSONDecoder` to use in further operations.
        enum Decoder<T> {
            /// The default `JSONDecoder` that has attached as `userInfo` any of the indicated associated values.
            case `default`(request: Bool = false, response: Bool = false, values: Bool = false)
            /// A custom `JSONDecoder` generated through the provided closure.
            case custom((_ request: URLRequest, _ response: HTTPURLResponse, _ values: T) throws -> JSONDecoder)
            /// A custom already-generated `JSONDecoder`.
            case predefined(JSONDecoder)
            
            /// Factory function creating a `JSONDecoder` from the receiving enum value.
            func makeDecoder(request: URLRequest, response: HTTPURLResponse, values: T) throws -> JSONDecoder {
                switch self {
                case .default(let includeRequest, let includeResponse, let includeValues):
                    let decoder = JSONDecoder()
                    if includeRequest  { decoder.userInfo[IG.API.JSON.DecoderKey.request] = request }
                    if includeResponse { decoder.userInfo[IG.API.JSON.DecoderKey.responseHeader] = response }
                    if includeValues   { decoder.userInfo[IG.API.JSON.DecoderKey.computedValues] = values }
                    return decoder
                case .custom(let g):
                    return try g(request, response, values)
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
