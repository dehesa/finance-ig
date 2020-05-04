import Foundation

extension Date {
    /// Returns the date from the last Tuesday.
    var lastTuesday: Date {
        let calendar = Calendar(identifier: .iso8601)
        let targetedWeekday = 3 // Sunday: 0, Monday: 1, Tuesday: 2
        
        let date = Date()
        var components = calendar.dateComponents([.hour, .minute, .second], from: date)
        components.weekday = targetedWeekday
        
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime, direction: .backward)!
    }
}

