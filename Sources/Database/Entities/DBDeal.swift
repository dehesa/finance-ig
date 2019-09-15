import Foundation

extension IG.DB {
    /// Measurement units are usually in pips or as percentage.
    public enum Unit: Int, CustomDebugStringConvertible {
        case points = 0
        case percentage = 1
        
        public var debugDescription: String {
            switch self {
            case .points:     return "points"
            case .percentage: return "%"
            }
        }
    }
}
