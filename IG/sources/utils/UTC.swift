import Foundation

/// UTC related variables.
public enum UTC {
    /// The default date formatter locale for UTC dates.
    public static let locale = Locale(identifier: "en_US_POSIX")
    /// The default timezone to be used in the API date formatters.
    public static let timezone = TimeZone(abbreviation: "UTC")!
    /// The default calendar to be used in the API date formatters.
    public static let calendar = Calendar(identifier: .iso8601).set {
        $0.timeZone = Self.timezone // The locale isn't set on purpose.
    }
}

extension UTC {
    /// Date and time using the UTC calendar and timezone as `DateFormatter` base.
    /// - Example: `2019-09-09 11:43:09`
    internal final class Timestamp {
        private var _components = DateComponents()
        private let _year = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        private let _month = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        private let _day = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        private let _hour = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        private let _minute = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        private let _second = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        
        deinit {
            self._year.deallocate()
            self._month.deallocate()
            self._day.deallocate()
            self._hour.deallocate()
            self._minute.deallocate()
            self._second.deallocate()
        }
        
        /// Returns the date represented by the given `String`, which must have the format `yyyy-MM-dd HH:mm:ss`.
        func date(from string: String) -> Date {
            let _ = withVaList([self._year, self._month, self._day, self._hour, self._minute, self._second]) {
                vsscanf(string, "%d-%d-%d %d:%d:%d", $0)
            }
            
            self._components.year = self._year.pointee
            self._components.month = self._month.pointee
            self._components.day = self._day.pointee
            self._components.hour = self._hour.pointee
            self._components.minute = self._minute.pointee
            self._components.second = self._second.pointee
            return UTC.calendar.date(from: self._components)!
        }
        
        /// Returns the string representation for the given `Date` with format `yyyy-MM-dd HH:mm:ss`.
        static func string(from date: Date) -> String {
            let components = UTC.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            
            var result = String()
            result.reserveCapacity(19)
            result.append(String(components.year!))
            result.append("-")
            result.append(String(components.month!))
            result.append("-")
            result.append(String(components.day!))
            result.append(" ")
            result.append(String(components.hour!))
            result.append(":")
            result.append(String(components.minute!))
            result.append(":")
            result.append(String(components.second!))
            return result
        }
    }
}
