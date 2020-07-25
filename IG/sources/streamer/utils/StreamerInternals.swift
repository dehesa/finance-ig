import Combine
import Foundation
import Decimals

extension Streamer {
    /// List of request data needed to make subscriptions.
    public enum Request {}

    /// Possible Lightstreamer modes.
    internal enum Mode: CustomStringConvertible {
        /// Lightstreamer MERGE mode.
        case merge
        /// Lightstreamer DISTINCT mode.
        case distinct
        /// Lightstreamer RAW mode.
        case raw
        /// Lightstreamer COMMAND mode.
        case command
        
        public var description: String {
            switch self {
            case .merge: return "MERGE"
            case .distinct: return "DISTINCT"
            case .raw: return "RAW"
            case .command: return "COMMAND"
            }
        }
    }
}

// MARK: - Convenience Formatter

internal extension Streamer {
    /// A packet value that has arrived by lightstreamer.
    typealias Packet = [String:Streamer.Row]
    
    /// A single field update.
    struct Row {
        /// Whether the field has been updated since the last udpate.
        let isUpdated: Bool
        /// The latest value.
        let value: String?
        /// Designated initializer.
        init(_ value: String?, isUpdated: Bool) {
            self.value = value
            self.isUpdated = isUpdated
        }
    }
}

internal extension Streamer.Packet {
    /// Decodes a value of the given type for the given key.
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - throws: `IG.Error` exclusively.
    func decodeIfPresent<Field>(_ type: String.Type, forKey key: Field) -> String? where Field: RawRepresentable, Field.RawValue==String {
        return self[key.rawValue]?.value
    }
    
    /// Decodes a value of the given type for the given key.
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - throws: `IG.Error` exclusively.
    func decodeIfPresent<Field>(_ type: Bool.Type, forKey key: Field) throws -> Bool? where Field: RawRepresentable, Field.RawValue==String {
        guard let value = self[key.rawValue]?.value else { return nil }
        switch value {
        case "0", "false": return false
        case "1", "true":  return true
        default: throw IG.Error._invalid(value: value, forKey: key)
        }
    }
    
    /// Decodes a value of the given type for the given key.
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - throws: `IG.Error` exclusively.
    func decodeIfPresent<Field>(_ type: Int.Type, forKey key: Field) throws -> Int? where Field: RawRepresentable, Field.RawValue==String {
        guard let value = self[key.rawValue]?.value else { return nil }
        return try Int(value) ?> IG.Error._invalid(value: value, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - throws: `IG.Error` exclusively.
    func decodeIfPresent<Field>(_ type: Decimal64.Type, forKey key: Field) throws -> Decimal64? where Field: RawRepresentable, Field.RawValue==String {
        guard let value = self[key.rawValue]?.value else { return nil }
        return try Decimal64(value) ?> IG.Error._invalid(value: value, forKey: key)
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// Transforms a value representing the time into a `Date` instance.
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - throws: `IG.Error` exclusively.
    func decodeIfPresent<Field>(_ type: Date.Type, with formatter: DateFormatter, forKey key: Field) throws -> Date? where Field: RawRepresentable, Field.RawValue==String {
        guard let value = self[key.rawValue]?.value else { return nil }
        
        let now = Date()
        guard let timeDate = formatter.date(from: value),
              let cal = formatter.calendar,
              let zone = formatter.timeZone,
              let mixDate = now.mixComponents([.year, .month, .day], withDate: timeDate, [.hour, .minute, .second], calendar: cal, timezone: zone) else {
            throw IG.Error._invalid(value: value, forKey: key)
        }
        
        return (mixDate <= now) ? mixDate : cal.date(byAdding: DateComponents(day: -1), to: mixDate)!
    }
    
    /// Decodes a value of the given type for the given key.
    ///
    /// Transform a value representing an Epoch date into a `Date` instance.
    /// - parameter type: The type of value to decode.
    /// - parameter key: The key that the decoded value is associated with.
    /// - throws: `IG.Error` exclusively.
    func decodeIfPresent<Field>(_ type: Date.Type, forKey key: Field) throws -> Date? where Field: RawRepresentable, Field.RawValue==String {
        guard let value = self[key.rawValue]?.value else { return nil }
        guard let milliseconds = TimeInterval(value) else { throw IG.Error._invalid(value: value, forKey: key) }
        return Date(timeIntervalSince1970: milliseconds / 1000)
    }
}

private extension IG.Error {
    /// Error raised when the response field contains an invalid value.
    static func _invalid(value: String, forKey key: Any) -> Self {
        Self(.streamer(.invalidResponse), "Invalid response field.", help: "Contact the repo maintainer and copy this error message.", info: ["Field": key, "Value": value])
    }
}
