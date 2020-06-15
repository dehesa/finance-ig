import Foundation

internal extension Date {
    /// Returns the date from the last Tuesday.
    var lastTuesday: Date {
        let (date, calendar) = (Date(), Calendar(identifier: .iso8601))
        var components = calendar.dateComponents([.hour, .minute, .second], from: date)
        components.weekday = 3 // Sunday: 0, Monday: 1, Tuesday: 2
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime, direction: .backward)!
    }
}
