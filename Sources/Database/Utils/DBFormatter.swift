import Foundation

extension IG.DB {
    /// Formatters (whether `DateFormatter`s, `NumberFormatter`s, etc.) used within the `DB` instance context.
    internal enum Formatter {
        /// Database *date* formatter.
        /// - Example: `2019-09-09`
        static let date = DateFormatter().set {
            $0.dateFormat = "yyyy-MM-dd"
            $0.calendar = IG.UTC.calendar
            $0.timeZone = IG.UTC.timezone
        }
        
        /// Database *timestamp* using the UTC calendar and timezone as `DateFormatter` base.
        /// - Example: `2019-09-09 11:43:09`
        static let timestamp = DateFormatter().set {
            $0.dateFormat = "yyyy-MM-dd HH:mm:ss"
            $0.calendar = IG.UTC.calendar
            $0.timeZone = IG.UTC.timezone
        }
    }
}

extension Bool {
    /// Returns a Boolean from a SQLite value.
    internal init(_ value: Int32) {
        self = value > 0
    }
}

extension Int32 {
    /// Returns the SQLite value for a boolean.
    internal init(_ value: Bool) {
        self = value ? 1 : 0
    }
}
