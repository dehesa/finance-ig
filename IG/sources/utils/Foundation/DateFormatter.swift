import Foundation

/// Reusable date and number formatters.
internal enum Formatter {
    /// Time formatter using the UTC calendar and timezone as `DateFormatter` base.
    /// - Format: `HH:mm:ss`
    /// - Example: `18:30:02`
    internal static let time = DateFormatter().set {
        $0.dateFormat = "HH:mm:ss"
        $0.calendar = IG.UTC.calendar
        $0.timeZone = IG.UTC.timezone
    }
    
    /// Time formatter (e.g. 17:30:29) for a date on London (including summer time if need be).
    static let londonTime = DateFormatter().set {
        $0.dateFormat = "HH:mm:ss"
        $0.calendar = Calendar(identifier: .iso8601)
        $0.timeZone = TimeZone(identifier: "Europe/London") ?! fatalError()
    }
    
    /// Month/Year formatter (e.g. SEP-18) using the UTC calendar and timezone as `DateFormatter` base.
    /// - Format: `MMM-yy`
    /// - Example: `DEC-19`
    static var dateDenormalBroad = DateFormatter().set {
        $0.dateFormat = "MMM-yy"
        $0.calendar = IG.UTC.calendar
        $0.timeZone = IG.UTC.timezone
    }
    
    /// Standard human readable format using the UTC calendar and timezone as `DateFormatter` base.
    /// - Format: `dd-MM-yy`
    /// - Example: `2019-11-25`
    internal static var dateDenormal = DateFormatter().set {
        $0.dateFormat = "dd-MMM-yy"
        $0.calendar = IG.UTC.calendar
        $0.timeZone = IG.UTC.timezone
    }
    
    /// Standard human readable format using the UTC calendar and timezone as `DateFormatter` base.
    /// - Format: `yyyy-MM-dd`
    /// - Example: `2019-11-25`
    internal static let date = DateFormatter().set {
        $0.dateFormat = "yyyy-MM-dd"
        $0.calendar = IG.UTC.calendar
        $0.timeZone = IG.UTC.timezone
    }
    
    /// Date and hours/seconds using UTC calendar and timezone as `DateFormatter` base.
    /// - Example: `2019-09-09 11:43`
    internal static var timestampBroad = DateFormatter().set {
        $0.dateFormat = "yyyy-MM-dd HH:mm"
        $0.calendar = IG.UTC.calendar
        $0.timeZone = IG.UTC.timezone
    }
    
    /// Date and time using the UTC calendar and timezone as `DateFormatter` base.
    /// - Example: `2019-09-09 11:43:09`
    internal static let timestamp = DateFormatter().set {
        $0.dateFormat = "yyyy-MM-dd HH:mm:ss"
        $0.calendar = IG.UTC.calendar
        $0.timeZone = IG.UTC.timezone
    }
    
    /// ISO 8601 (without timezone) using the UTC calendar and timezone as `DateFormatter` base.
    /// - Format: `yyyy-MM-dd'T'HH:mm:ss`
    /// - Example: `2019-11-25T22:33:11`
    static let iso8601Broad = DateFormatter().set {
        $0.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        $0.calendar = IG.UTC.calendar
        $0.timeZone = IG.UTC.timezone
    }
    
    /// ISO 8601 (with milliseconds and without timezone) using the UTC calendar and timezone as `DateFormatter` base.
    /// - Format: `yyyy-MM-dd'T'HH:mm:ss.SSS`
    /// - Example: `2019-11-25T22:33:11.100`
    internal static let iso8601 = DateFormatter().set {
        $0.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        $0.calendar = IG.UTC.calendar
        $0.timeZone = IG.UTC.timezone
    }
    
    /// ISO 8601 (without timezone) using the UTC calendar and timezone as `DateFormatter` base.
    /// - Format: `yyyy-MM-dd'T'HH:mm`
    /// - Example: `2019-11-25T22:33`
    static let iso8601NoSeconds = DateFormatter().set {
        $0.dateFormat = "yyyy-MM-dd'T'HH:mm"
        $0.calendar = IG.UTC.calendar
        $0.timeZone = IG.UTC.timezone
    }
    
    /// Standard human readable format using the UTC calendar and timezone as `DateFormatter` base.
    /// - Format: `yyyy/MM/dd HH:mm:ss`
    /// - Example: `2019/11/25 22:33:11`
    static var humanReadable = DateFormatter().set {
        $0.dateFormat = "yyyy/MM/dd HH:mm:ss"
        $0.calendar = IG.UTC.calendar
        $0.timeZone = IG.UTC.timezone
    }
    
    /// Default date formatter for the date provided in one HTTP header key/value using the UTC calendar and timezone as `DateFormatter` base.
    /// - Format: `E, d MMM yyyy HH:mm:ss zzz`
    /// - Example: `Sat, 29 Aug 2019 07:06:30 GMT`
    static let humanReadableLong = DateFormatter().set {
        $0.dateFormat = "E, d MMM yyyy HH:mm:ss zzz"
        $0.calendar = IG.UTC.calendar
        $0.timeZone = IG.UTC.timezone
    }
}

extension DateFormatter {
    /// Makes a deep copy of the passed `DateFormatter`.
    /// - requires: `NSCopying` inheritance to work.
    internal var deepCopy: DateFormatter {
        self.copy() as! DateFormatter
    }
    
    /// Makes a deep copy of the passed `DateFormatter` and sets the time zone on the copy.
    /// - requires: `NSCopying` inheritance to work. 
    internal func deepCopy(timeZone: TimeZone) -> DateFormatter {
        self.deepCopy.set { $0.timeZone = timeZone }
    }
}

extension Locale {
    /// The locale used by default.
    static let london: Locale = .init(identifier: "en_GB")
}
