import Foundation

/// UTC related variables.
internal enum UTC {
    /// The default calendar to be used in the API date formatters.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = UTC.timezone
        return calendar
    }()
    /// The default timezone to be used in the API date formatters.
    static let timezone = TimeZone(abbreviation: "UTC")!
    /// The default date formatter locale for UTC dates.
    static let locale = Locale(identifier: "en_US_POSIX")
}

extension Foundation.DateFormatter {
    /// Configures a formatter for the module UTC representation and decoding.
    internal func configureForUTC() {
        self.calendar = UTC.calendar
        self.timeZone = UTC.timezone
        self.locale = UTC.locale
    }
}

extension Foundation.Date {
    /// Convenience initializer for dates grounded in UTC.
    internal init?(year: Int, month: Int, day: Int? = nil, hour: Int? = nil, minute: Int? = nil, second: Int? = nil, calendar: Calendar = UTC.calendar, timezone: TimeZone = UTC.timezone) {
        let components = DateComponents(calendar: calendar, timeZone: timezone, year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        guard let date = components.date else { return nil }
        self = date
    }
    
    /// Returns the date for the last day, hour, minute, and second of the month.
    internal var lastDayOfMonth: Date {
        let (calendar, timezone) = (UTC.calendar, UTC.timezone)
        
        var components = calendar.dateComponents(in: timezone, from: self)
        components.timeZone = timezone
        components.month = components.month! + 1
        components.hour = 0
        components.minute = 0
        components.second = -1
        components.nanosecond = 0
        return components.date!
    }
    
    /// Checks whether the receiving date is the last day of the month.
    internal var isLastDayOfMonth: Bool {
        let calendar = UTC.calendar
        let selfDay = calendar.component(.day, from: self)
        let lastDay = calendar.component(.day, from: self.lastDayOfMonth)
        return selfDay == lastDay
    }
    
    /// Mixed the components from the receiving date and the argument date with the given calendar and timezone.
    /// - parameters receivingComponents: The selected components from the receiving date.
    /// - parameters date: The other date from which to mix components.
    /// - parameters dateComponents: The selected components from the argument date.
    /// - parameters calendar: The calendar used to extract components.
    /// - parameters timezone: The timezone used to extract components.
    internal func mixComponents(_ receivingComponents: Set<Calendar.Component>, withDate date: Date, _ dateComponents: Set<Calendar.Component>, calendar: Calendar, timezone: TimeZone) -> Date? {
        let left = calendar.dateComponents(in: timezone, from: self)
        let right = calendar.dateComponents(in: timezone, from: date)
        var mixed = DateComponents(calendar: calendar, timeZone: timezone)
        
        for (selectedComponents, parsedComponents) in [(receivingComponents, left), (dateComponents, right)] {
            for component in selectedComponents {
                guard let value = parsedComponents.value(for: component) else { continue }
                mixed.setValue(value, for: component)
            }
        }
        
        return mixed.date
    }
}
