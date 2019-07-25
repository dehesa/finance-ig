import Foundation

extension Streamer {
    /// Reusable streamer date formatter utility instances.
    internal enum DateFormatter {
        /// Time formatter (e.g. 17:30:29).
        static var time: DateFormatter { return API.DateFormatter.time }
    }
    
    /// Default codecs (encoders/decoders) for requests/responses.
    internal enum Codecs {
        /// Default JSON decoder returning the request and response header in its user info dictionary.
        static let jsonDecoder = JSONDecoder()
    }
}
