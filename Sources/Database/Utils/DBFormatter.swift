import Foundation

extension IG.DB {
    /// Formatters (whether `DateFormatter`s, `NumberFormatter`s, etc.) used within the `DB` instance context.
    internal enum Formatter {
        /// Database *timestamp* using the UTC calendar and timezone as `DateFormatter` base.
        /// - Example: `2019-09-09 11:43:09`
        static var timestamp: DateFormatter {
            return IG.Formatter.timestamp
        }
        
        /// Database *date* formatter (only giving `yyyy-MM-dd`).
        /// - Example: `2019-09-09`
        static var date: DateFormatter {
            return IG.Formatter.date
        }
        
        /// Database *time* formatter (only giving `HH:mm:ss`).
        /// - Example: `11:43:09`
        static var time: DateFormatter {
            return IG.Formatter.time
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
