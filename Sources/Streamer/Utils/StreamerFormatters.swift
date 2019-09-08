import Foundation

extension IG.Streamer {
    /// Formatters (whether `DateFormatter`s, `NumberFormatter`s, etc.) used within the `Streamer` instance context.
    internal enum Formatter {
        /// Time formatter (e.g. 17:30:29) for a date on London (including summer time if need be).
        static let time = DateFormatter().set {
            $0.dateFormat = "HH:mm:ss"
            $0.calendar = Calendar(identifier: .iso8601)
            $0.timeZone = TimeZone(identifier: "Europe/London")!
        }
        /// ISO 8601 (without timezone) using the UTC calendar and timezone as `DateFormatter` base.
        /// - Format: `yyyy-MM-dd'T'HH:mm:ss.SSS`
        /// - Example: `2019-11-25T22:33:11.100`
        static var iso8601miliseconds: DateFormatter {
            return IG.API.Formatter.iso8601miliseconds
        }
    }
}

extension IG.Streamer.Formatter {
    /// Functionality related to updates brought by the `Streamer`.
    internal enum Update {
        /// Transform a `String` representing a Boolean value into an actual `Bool` value.
        /// - parameter value: The `String` value representing the result.
        /// - throws: `IG.Streamer.Formatter.Update.Error` exclusively.
        static func toBoolean(_ value: String) throws -> Bool {
            switch value {
            case "0", "false": return false
            case "1", "true":  return true
            default: throw Self.Error(value: value, to: Bool.self)
            }
        }
        /// Transforms a `String` representing an integer into an actual `Int` value.
        /// - parameter value: The `String` value representing the result.
        /// - throws: `IG.Streamer.Formatter.Update.Error` exclusively.
        static func toInt(_ value: String) throws -> Int {
            return try Int(value) ?! Self.Error(value: value, to: Int.self)
        }
        /// Transforms a `String` representing a decimal number (could be a floating-point number) into an actual `Decimal` value.
        /// - parameter value: The `String` value representing the result.
        /// - throws: `IG.Streamer.Formatter.Update.Error` exclusively.
        static func toDecimal(_ value: String) throws -> Decimal {
            return try Decimal(string: value) ?! Self.Error(value: value, to: Decimal.self)
        }
        /// Transforms a `String` representing the time (without any more "date" information into a `Date` instance.
        /// - parameter value: The `String` value representing the result.
        /// - returns: The time given in `value` of today.
        /// - throws: `IG.Streamer.Formatter.Update.Error` exclusively.
        static func toTime(_ value: String, timeFormatter: DateFormatter) throws -> Date {
            let now = Date()
            let formatter = IG.Streamer.Formatter.time
            guard let cal = formatter.calendar, let zone = formatter.timeZone,
                  let timeDate = formatter.date(from: value),
                  let mixDate = now.mixComponents([.year, .month, .day], withDate: timeDate, [.hour, .minute, .second], calendar: cal, timezone: zone) else {
                throw Self.Error(value: value, to: Date.self)
            }
            
            guard mixDate > now else { return mixDate }
            let newDate = try cal.date(byAdding: DateComponents(day: -1), to: mixDate) ?! Self.Error(value: value, to: Date.self)
            return newDate
        }
        /// Transforms a `String` representing an Epoch date into a `Date` instance.
        /// - parameter value: The `String` value representing the result.
        /// - returns: The time given in `value` of today.
        /// - throws: `IG.Streamer.Formatter.Update.Error` exclusively.
        static func toEpochDate(_ value: String) throws -> Date {
            let milliseconds = try TimeInterval(value) ?! Self.Error(value: value, to: Date.self)
            return Date(timeIntervalSince1970: milliseconds / 1000)
        }
        /// Transforms a `String` representing a raw value type.
        /// - parameter value: The `String` value representing the result.
        /// - throws: `IG.Streamer.Formatter.Update.Error` exclusively. 
        static func toRawType<T>(_ value: String) throws -> T where T:RawRepresentable, T.RawValue == String {
            return try T.init(rawValue: value) ?! Self.Error(value: value, to: T.self)
        }
        
        /// Represents an error that happen when transforming an updated value from a `String` to a type `T` representation.
        internal struct Error: Swift.Error {
            /// The value to be transformed from.
            let value: String
            /// The type of the result of the transformation.
            let type: String
            /// Designated initializer.
            init<T>(value: String, to type: T.Type) {
                self.value = value
                self.type = String(describing: type)
            }
        }
    }
}

extension IG.Streamer.Formatter.Update.Error: IG.ErrorPrintable {
    var printableDomain: String {
        return "IG.\(Streamer.self).\(Streamer.Formatter.self).\(Streamer.Formatter.Update.self).\(Streamer.Formatter.Update.Error.self)"
    }
    
    var printableType: String {
        return self.type
    }
    
    func printableMultiline(level: Int) -> String {
        let prefix = Self.debugPrefix(level: level+1)
        
        var result = self.printableDomain
        result.append("\(prefix)Updating to type: \(self.printableType)")
        result.append("\(prefix)Value: \(self.value)")
        return result
    }
}

