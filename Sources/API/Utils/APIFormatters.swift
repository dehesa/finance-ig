import Foundation

// MARK: - Date Formatters

extension API {
    /// Reusable date formatter utility instances.
    internal enum TimeFormatter {
        /// ISO 8601 (without timezone).
        static let iso8601Miliseconds = DateFormatter().set {
            $0.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
            $0.calendar = UTC.calendar
            $0.timeZone = UTC.timezone

        }
        /// ISO 8601 (without timezone).
        static let iso8601NoTimezone = DateFormatter().set {
            $0.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            $0.calendar = UTC.calendar
            $0.timeZone = UTC.timezone
        }
        
        /// ISO 8601 (without timezone).
        static let iso8601NoTimezoneSeconds = DateFormatter().set {
            $0.dateFormat = "yyyy-MM-dd'T'HH:mm"
            $0.calendar = UTC.calendar
            $0.timeZone = UTC.timezone
        }
        
        /// Month/Year formatter (e.g. SEP-18).
        static let monthYear = DateFormatter().set {
            $0.dateFormat = "MMM-yy"
            $0.calendar = UTC.calendar
            $0.timeZone = UTC.timezone
        }
        
        /// Standard human readable format (e.g. 2018/06/16).
        static let yearMonthDay = DateFormatter().set {
            $0.dateFormat = "yyyy-MM-dd"
            $0.calendar = UTC.calendar
            $0.timeZone = UTC.timezone
        }
        
        /// Month/Day formatter (e.g. DEC29).
        static let dayMonthYear = DateFormatter().set {
            $0.dateFormat = "dd-MMM-yy"
            $0.calendar = UTC.calendar
            $0.timeZone = UTC.timezone
        }
        
        /// Time formatter (e.g. 17:30:29).
        static let time = DateFormatter().set {
            $0.dateFormat = "HH:mm:ss"
            $0.calendar = UTC.calendar
            $0.timeZone = UTC.timezone
        }
        
        /// Standard human readable format (e.g. 2018/06/16 16:24:03).
        static let humanReadable = DateFormatter().set {
            $0.dateFormat = "yyyy/MM/dd HH:mm:ss"
            $0.calendar = UTC.calendar
            $0.timeZone = UTC.timezone
        }
        
        /// Default date formatter for the date provided in one HTTP header key/value.
        static let humanReadableLong = DateFormatter().set {
            $0.dateFormat = "E, d MMM yyyy HH:mm:ss zzz"
            $0.calendar = UTC.calendar
            $0.timeZone = UTC.timezone
        }
    }
}

extension DateFormatter {
    /// Makes a deep copy of the passed `DateFormatter`.
    /// - todo: Check whether it works in non Darwin systems.
    internal var deepCopy: DateFormatter {
        return self.copy() as! DateFormatter
    }
}
