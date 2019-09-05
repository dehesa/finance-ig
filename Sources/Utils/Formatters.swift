import Foundation

/// Reusable date and number formatters.
internal enum Formatter {
    /// - precondition: Either `dateFormat` or `timeFormat` must be set. If not, this function will return the normal ISO date formatter.
    static func date(_ dateFormat: Self.DateFormat? = .yearMonthDay, time timeFormat: Self.TimeFormat? = .normal, localize: Bool = false) -> DateFormatter {
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
            return API.Formatter.iso8601
        }
        
        let result = DateFormatter()
        result.calendar = Calendar(identifier: .iso8601)
        result.timeZone = (localize) ? .current : IG.UTC.timezone
        result.dateFormat = format
        return result
    }
    
    enum DateFormat {
        case yearMonth
        case yearMonthDay
    }
    
    enum TimeFormat {
        case hoursMinutes
        case normal
        case detailed
    }
}
