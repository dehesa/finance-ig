import Foundation

/// The format of the mocked JSON files representing API responses.
struct APIMockedJSON: Decodable {
    /// The status code for the mocked endpoint.
    let statusCode: Int
    /// The header fields (if any) for the mocked endpoint.
    let header: [String:String]?
    /// The JSON body (if any) for the mocked endpoint.
    let body: AnyCodable?
}
