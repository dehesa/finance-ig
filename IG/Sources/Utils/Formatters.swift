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
    
    /// Month/Year formatter (e.g. SEP-18) using the UTC calendar and timezone as `DateFormatter` base.
    /// - Format: `MMM-yy`
    /// - Example: `DEC-19`
    static var dateDenormalBroad: DateFormatter {
        DateFormatter().set {
            $0.dateFormat = "MMM-yy"
            $0.calendar = IG.UTC.calendar
            $0.timeZone = IG.UTC.timezone
        }
    }
    
    /// Standard human readable format using the UTC calendar and timezone as `DateFormatter` base.
    /// - Format: `dd-MM-yy`
    /// - Example: `2019-11-25`
    internal static var dateDenormal: DateFormatter {
        DateFormatter().set {
            $0.dateFormat = "dd-MMM-yy"
            $0.calendar = IG.UTC.calendar
            $0.timeZone = IG.UTC.timezone
        }
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
    internal static var timestampBroad: DateFormatter {
        DateFormatter().set {
            $0.dateFormat = "yyyy-MM-dd HH:mm"
            $0.calendar = IG.UTC.calendar
            $0.timeZone = IG.UTC.timezone
        }
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
}

extension DateFormatter {
    /// Makes a deep copy of the passed `DateFormatter`.
    /// - requires: `NSCopying` inheritance to work.
    internal var deepCopy: DateFormatter {
        return self.copy() as! DateFormatter
    }
    
    /// Makes a deep copy of the passed `DateFormatter` and sets the time zone on the copy.
    /// - requires: `NSCopying` inheritance to work. 
    internal func deepCopy(timeZone: TimeZone) -> DateFormatter {
        return self.deepCopy.set { $0.timeZone = timeZone }
    }
}

extension Locale {
    /// The locale used by default.
    static let ig: Locale = .init(identifier: "en_GB")
}
