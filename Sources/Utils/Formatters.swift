import Foundation

/// Reusable date and number formatters.
internal enum Formatter {
    /// Database *timestamp* using the UTC calendar and timezone as `DateFormatter` base.
    /// - Example: `2019-09-09 11:43:09`
    static let fullDate = DateFormatter().set {
        $0.dateFormat = "yyyy-MM-dd HH:mm:ss"
        $0.calendar = IG.UTC.calendar
        $0.timeZone = IG.UTC.timezone
    }
    
    /// Time formatter using the UTC calendar and timezone as `DateFormatter` base.
    /// - Format: `HH:mm:ss`
    /// - Example: `18:30:02`
    internal static let time = DateFormatter().set {
        $0.dateFormat = "HH:mm:ss"
        $0.calendar = IG.UTC.calendar
        $0.timeZone = IG.UTC.timezone
    }
    
    /// Standard human readable format using the UTC calendar and timezone as `DateFormatter` base.
    /// - Format: `yyyy-MM-dd`
    /// - Example: `2019-11-25`
    internal static let yearMonthDay = DateFormatter().set {
        $0.dateFormat = "yyyy-MM-dd"
        $0.calendar = IG.UTC.calendar
        $0.timeZone = IG.UTC.timezone
    }
}

extension IG.Formatter {
    enum DateFormat {
        case yearMonth
        case yearMonthDay
    }
    
    enum TimeFormat {
        case hoursMinutes
        case normal
        case detailed
    }
    
    /// - precondition: Either `dateFormat` or `timeFormat` must be set. If not, this function will return the normal ISO date formatter.
    internal static func date(_ dateFormat: Self.DateFormat? = .yearMonthDay, time timeFormat: Self.TimeFormat? = .normal, localize: Bool = false) -> DateFormatter {
        var format: String
        let space: String
        
        switch dateFormat {
        case .none:
            format = String()
            space = String()
        case .yearMonthDay:
            format = "yyyy.MM.dd"
            space = " "
        case .yearMonth:
            format = "yyyy.MM"
            space = " "
        }
        
        switch timeFormat {
        case .none: break
        case .normal:
            format.append(space)
            format.append("HH:mm:ss")
        case .detailed:
            format.append(space)
            format.append("HH:mm:ss.SSS")
        case .hoursMinutes:
            format.append(space)
            format.append("HH:mm")
        }
        
        guard !format.isEmpty else {
            return IG.Formatter.fullDate
        }
        
        let result = DateFormatter()
        result.calendar = Calendar(identifier: .iso8601)
        result.timeZone = (localize) ? .current : IG.UTC.timezone
        result.dateFormat = format
        return result
    }
}
