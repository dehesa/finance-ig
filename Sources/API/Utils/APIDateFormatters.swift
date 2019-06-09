import Foundation

extension API {
    /// Reusable date formatter utility instances.
    internal enum DateFormatter {
        /// ISO 8601 (without timezone).
        static let iso8601Miliseconds = Foundation.DateFormatter().set {
            $0.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
            $0.configureForUTC()
        }
        /// ISO 8601 (without timezone).
        static let iso8601NoTimezone = Foundation.DateFormatter().set {
            $0.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            $0.configureForUTC()
        }
        
        /// ISO 8601 (without timezone).
        static let iso8601NoTimezoneSeconds = Foundation.DateFormatter().set {
            $0.dateFormat = "yyyy-MM-dd'T'HH:mm"
            $0.configureForUTC()
        }
        
        /// Month/Year formatter (e.g. SEP-18).
        static let monthYear = Foundation.DateFormatter().set {
            $0.dateFormat = "MMM-yy"
            $0.configureForUTC()
        }
        
        /// Month/Day formatter (e.g. DEC29).
        static let dayMonthYear = Foundation.DateFormatter().set {
            $0.dateFormat = "dd-MMM-yy"
            $0.configureForUTC()
        }
        
        /// Time formatter (e.g. 17:30:29).
        static let time = Foundation.DateFormatter().set {
            $0.dateFormat = "HH:mm:ss"
            $0.configureForUTC()
        }
        
        /// Standard human readable format (e.g. 2018/06/16 16:24:03).
        static let humanReadable = Foundation.DateFormatter().set {
            $0.dateFormat = "yyyy/MM/dd HH:mm:ss"
            $0.configureForUTC()
        }
        
        /// Standard human readable format (e.g. 2018/06/16).
        static let humanReadableNoTime = Foundation.DateFormatter().set {
            $0.dateFormat = "yyyy/MM/dd"
            $0.configureForUTC()
        }
        
        /// Default date formatter for the date provided in one HTTP header key/value.
        static let humanReadableLong = Foundation.DateFormatter().set {
            $0.dateFormat = "E, d MMM yyyy HH:mm:ss zzz"
            $0.configureForUTC()
        }
        
        /// Makes a deep copy of the passed `DateFormatter`.
        /// - todo: Check whether it works in non Darwin systems.
        static func deepCopy(_ formatter: Foundation.DateFormatter) -> Foundation.DateFormatter {
            return formatter.copy() as! Foundation.DateFormatter
        }
    }
    
    /// Default codecs (encoders/decoders) for requests/responses.
    internal enum Codecs {
        /// Default JSON encoder.
        static func jsonEncoder() -> JSONEncoder {
            return JSONEncoder()
        }
        
        /// Default JSON decoder returning the request and response header in its user info dictionary.
        static func jsonDecoder(request: URLRequest, responseHeader: HTTPURLResponse) -> JSONDecoder {
            let result = JSONDecoder()
            result.userInfo[.urlRequest] = request
            result.userInfo[.responseHeader] = responseHeader
            return result
        }
    }
}
