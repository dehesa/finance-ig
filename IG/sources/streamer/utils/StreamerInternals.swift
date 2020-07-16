import Combine
import Foundation
import Decimals

extension Streamer {
    /// List of request data needed to make subscriptions.
    public enum Request {}

    /// Possible Lightstreamer modes.
    internal enum Mode: String {
        /// Lightstreamer MERGE mode.
        case merge = "MERGE"
        /// Lightstreamer DISTINCT mode.
        case distinct = "DISTINCT"
        /// Lightstreamer RAW mode.
        case raw = "RAW"
        /// Lightstreamer COMMAND mode.
        case command = "COMMAND"
    }
}

// MARK: - Convenience Formatter

internal extension Streamer {
    /// Functionality related to updates brought by the `Streamer`.
    enum Update {
        /// Transform a `String` representing a Boolean value into an actual `Bool` value.
        /// - parameter value: The `String` value representing the result.
        /// - throws: `Streamer.Update.Error` exclusively.
        static func toBoolean(_ value: String) throws -> Bool {
            switch value {
            case "0", "false": return false
            case "1", "true":  return true
            default: throw Self.Error(value: value, to: Bool.self)
            }
        }
        /// Transforms a `String` representing an integer into an actual `Int` value.
        /// - parameter value: The `String` value representing the result.
        /// - throws: `Streamer.Update.Error` exclusively.
        static func toInt(_ value: String) throws -> Int {
            try Int(value) ?> Self.Error(value: value, to: Int.self)
        }
        /// Transforms a `String` representing a decimal number (could be a floating-point number) into an actual `Decimal64` value.
        /// - parameter value: The `String` value representing the result.
        /// - throws: `Streamer.Update.Error` exclusively.
        static func toDecimal(_ value: String) throws -> Decimal64 {
            try Decimal64(value) ?> Self.Error(value: value, to: Decimal64.self)
        }
        /// Transforms a `String` representing the time (without any more "date" information into a `Date` instance.
        /// - parameter value: The `String` value representing the result.
        /// - returns: The time given in `value` of today.
        /// - throws: `Streamer.Update.Error` exclusively.
        static func toTime(_ value: String, timeFormatter: DateFormatter) throws -> Date {
            let now = Date()
            let formatter = DateFormatter.londonTime
            guard let cal = formatter.calendar, let zone = formatter.timeZone,
                let timeDate = formatter.date(from: value),
                let mixDate = now.mixComponents([.year, .month, .day], withDate: timeDate, [.hour, .minute, .second], calendar: cal, timezone: zone) else {
                    throw Self.Error(value: value, to: Date.self)
            }
            
            guard mixDate > now else { return mixDate }
            let newDate = try cal.date(byAdding: DateComponents(day: -1), to: mixDate) ?> Self.Error(value: value, to: Date.self)
            return newDate
        }
        /// Transforms a `String` representing an Epoch date into a `Date` instance.
        /// - parameter value: The `String` value representing the result.
        /// - returns: The time given in `value` of today.
        /// - throws: `Streamer.Update.Error` exclusively.
        static func toEpochDate(_ value: String) throws -> Date {
            let milliseconds = try TimeInterval(value) ?> Self.Error(value: value, to: Date.self)
            return Date(timeIntervalSince1970: milliseconds / 1000)
        }
        /// Transforms a `String` representing a raw value type.
        /// - parameter value: The `String` value representing the result.
        /// - throws: `Streamer.Update.Error` exclusively.
        static func toRawType<T>(_ value: String) throws -> T where T:RawRepresentable, T.RawValue == String {
            try T.init(rawValue: value) ?> Self.Error(value: value, to: T.self)
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
