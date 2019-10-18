import Foundation

extension IG.API {
    /// Reusable date formatter utility instances.
    internal enum Formatter {
        /// Time formatter using the UTC calendar and timezone as `DateFormatter` base.
        /// - Format: `HH:mm:ss`
        /// - Example: `18:30:02`
        static var time: DateFormatter {
            return IG.Formatter.time
        }

        /// Standard human readable format using the UTC calendar and timezone as `DateFormatter` base.
        /// - Format: `yyyy-MM-dd`
        /// - Example: `2019-11-25`
        static var date: DateFormatter {
            return IG.Formatter.date
        }

        /// Month/Year formatter (e.g. SEP-18) using the UTC calendar and timezone as `DateFormatter` base.
        /// - Format: `MMM-yy`
        /// - Example: `DEC-19`
        static var dateDenormalBroad: DateFormatter {
            return IG.Formatter.dateDenormalBroad
        }
        
        /// Debuggable-friendly *timestamp* using the UTC calendar and timezone as `DateFormatter` base.
        /// - Example: `2019-09-09 11:43:09`
        static var timestamp: DateFormatter {
            return IG.Formatter.timestamp
        }

        /// ISO 8601 (without timezone) using the UTC calendar and timezone as `DateFormatter` base.
        /// - Format: `yyyy-MM-dd'T'HH:mm:ss`
        /// - Example: `2019-11-25T22:33:11`
        static var iso8601Broad: DateFormatter {
            return IG.Formatter.iso8601Broad
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
        static var humanReadable: DateFormatter {
            return DateFormatter().set {
                $0.dateFormat = "yyyy/MM/dd HH:mm:ss"
                $0.calendar = IG.UTC.calendar
                $0.timeZone = IG.UTC.timezone
            }
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
}
