import Foundation

/// List of functionality helping to translate errors into `String`s.
internal enum ErrorHelper {
    /// Returns a single-line `String` representation of the passed value taking a given prefix and a maximum number of characters per line.
    internal static func representation(of value: Any, prefixCount: Int, maxCharacters: Int, replacingNewLinesWith replace: String? = " ") -> String {
        let string = (value as? String) ?? String(describing: value)
        guard !string.isEmpty else { return "" }
        
        let maxCount = max(maxCharacters - prefixCount, 0)
        let end = string.index(string.startIndex, offsetBy: maxCount, limitedBy: string.endIndex) ?? string.endIndex
        
        let result = String(string[..<end])
        guard let char = replace, !char.isEmpty else { return result }
        return result.replacingOccurrences(of: "\n", with: char)
    }
    
    /// Returns a multi-line representation of the passed error.
    internal static func representation(of underlyingError: Swift.Error?, level: Int, prefixCount: Int, maxCharacters: Int) -> String? {
        switch underlyingError {
        case .none:
            return nil
        case let printableError as IG.ErrorPrintable:
            return printableError.printableMultiline(level: level+1)
        case let unknownError?:
            return IG.ErrorHelper.representation(of: unknownError, prefixCount: prefixCount, maxCharacters: maxCharacters)
        }
    }
    
    /// Returns a multi-line representation of the given error context.
    internal static func representation(of context: [IG.Error.Item], itemPrefix: String, maxCharacters: Int) -> String {
        var result = String()
        
        for (title, value) in context {
            let beginning = "\(itemPrefix)\(title): "
            result.append(beginning)
            
            switch value {
            case let string as String:
                result.append(IG.ErrorHelper.representation(of: string, prefixCount: beginning.count, maxCharacters: maxCharacters))
            case let decimal as Decimal:
                result.append(String(describing: decimal))
            case let date as Date:
                result.append(IG.Formatter.timestamp.string(from: date))
            case let request as URLRequest:
                var stringValue = String()
                if let method = request.httpMethod { stringValue.append("\(method) ") }
                if let url = request.url { stringValue.append("\(url) ") }
                result.append(stringValue)
            case let response as URLResponse:
                result.append(IG.ErrorHelper.representation(of: response, prefixCount: beginning.count, maxCharacters: maxCharacters))
            case let limit as IG.Deal.Limit:
                result.append(Self.representation(of: limit.type))
            case let stop as IG.Deal.Stop:
                result.append(Self.representation(of: stop.type))
                result.append(", ")
                switch stop.risk {
                case .exposed:
                    result.append("exposed risk")
                case .limited(let premium):
                    result.append("limited risk")
                    if let comission = premium {
                        result.append(#" (premium "\#(comission)""#)
                    }
                }
                switch stop.trailing {
                case .static: break
                case .dynamic(let settings):
                    result.append(", trailing")
                    if let s = settings {
                        result.append(#" distance "\#(s.distance)", increment "\#(s.increment)""#)
                    }
                }
            case let stopType as IG.Deal.Stop.Kind:
                result.append(Self.representation(of: stopType))
            case let stopTrailing as IG.Deal.Stop.Trailing:
                switch stopTrailing {
                case .static: result.append("static")
                case .dynamic(let settings):
                    result.append("dynamic")
                    if let s = settings {
                        result.append(#" distance "\#(s.distance)", increment "\#(s.increment)""#)
                    }
                }
            case let code as IG.SQLite.Result:
                result.append("\(code.rawValue) -> \(code.description)")
            case let errors as [IG.Streamer.Error]:
                let string = errors.map {
                    var s = $0.printableType
                    if let item = $0.item { s.append(" for \(item)") }
                    return s
                }.joined(separator: ", ")
                result.append("[\(string)]")
            case let statuses as [IG.Streamer.Session.Status]:
                let string = statuses.map { $0.rawValue }.joined(separator: ", ")
                result.append("[\(string)]")
            case let updates as [String:IG.Streamer.Subscription.Update]:
                let string = updates.map { "\($0): \($1.value ?? "nil")" }.joined(separator: ", ")
                result.append("[\(string)]")
            default:
                result.append(IG.ErrorHelper.representation(of: value, prefixCount: beginning.count, maxCharacters: maxCharacters))
            }
        }
        
        return result
    }
    
    /// Returns a `String` representation of a deal limit type.
    /// - parameter limitType: A type of limit for a given deal.
    /// - returns: A representation for a deal's limit.
    private static func representation(of limitType: IG.Deal.Limit.Kind) -> String {
        switch limitType {
        case .distance(let distance): return #"distance "\#(distance)""#
        case .position(let level):    return #"level "\#(level)""#
        }
    }
    
    /// Returns a `String` representation of a deal stop type.
    /// - parameter limitType: A type of stop for a given deal.
    /// - returns: A representation for a deal's stop.
    private static func representation(of stopType: IG.Deal.Stop.Kind) -> String {
        switch stopType {
        case .distance(let distance): return #"distance "\#(distance)""#
        case .position(let level):    return #"level "\#(level)""#
        }
    }
}
