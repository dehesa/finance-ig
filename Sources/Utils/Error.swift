import Foundation

/// Errors thrown by the IG framework.
public protocol Error: Swift.Error, CustomDebugStringConvertible {
    /// The error subtype within this errors domain.
    associatedtype Kind: CaseIterable
    
    /// The type of error.
    var type: Self.Kind { get }
    /// A message accompaigning the error explaining what happened.
    var message: String { get }
    /// Possible solutions for the problem.
    var suggestion: String { get }
    /// Any underlying error that was raised right before this hosting error.
    var underlyingError: Swift.Error? { get }
    /// Store values/objects that gives context to the hosting error.
    var context: [(title: String, value: Any)] { get }
}

internal protocol ErrorPrintable {
    /// The human readable error domain.
    var printableDomain: String { get }
    /// The human readable error type.
    var printableType: String { get }
}

extension IG.Error where Self: IG.ErrorPrintable {
    /// Prefix to append before any new line when making a human readable version of the error.
    internal static var prefix: String { "\n\t" }
    /// Header to be appended to any human readable version of the error.
    internal var printableHeader: String {
        var result = "\n\n[\(self.printableDomain)] \(self.printableType)."
        result.append("\(Self.prefix)Description: \(self.message)")
        result.append("\(Self.prefix)Suggestions: \(self.suggestion)")
        return result
    }
    /// Human readable version of the underlying error.
    internal var printableUnderlyingError: String? {
        guard let subError = self.underlyingError else { return nil }
        var attachedError: Swift.Error? = nil
        
        var result = "\(Self.prefix)Underlying "
        // MARK: Foundation.EncodingError
        if let encodingError = subError as? EncodingError {
            result.append("encoding error: ")
            switch encodingError {
            case .invalidValue(let value, let ctx):
                result.append(#"Invalid value at coding path "\#(ctx.codingPath.printableString)"."#)
                result.append("\(Self.prefix)\t\(ctx.debugDescription)")
                result.append("\(Self.prefix)\t\(String(describing: value))")
                attachedError = ctx.underlyingError
            @unknown default:
                result.append("Non-identifyiable.")
            }
        // MARK: Foundation.DecodingError
        } else if let decodingError = subError as? DecodingError {
            result.append("decoding error: ")
            switch decodingError {
            case .keyNotFound(let key, let ctx):
                result.append(#"Key "\#(key.printableString)" not found at coding path "\#(ctx.codingPath.printableString)"."#)
                result.append("\(Self.prefix)\t\(ctx.debugDescription)")
                attachedError = ctx.underlyingError
            case .valueNotFound(let type, let ctx):
                result.append(#"Value of type "\#(type.self)" not found at coding path "\#(ctx.codingPath.printableString)"."#)
                result.append("\(Self.prefix)\t\(ctx.debugDescription)")
                attachedError = ctx.underlyingError
            case .typeMismatch(let type, let ctx):
                result.append(#"Mismatch of expected value type "\#(type.self)" at coding path "\#(ctx.codingPath.printableString)"."#)
                result.append("\(Self.prefix)\t\(ctx.debugDescription)")
                attachedError = ctx.underlyingError
            case .dataCorrupted(let ctx):
                result.append(#"Data corrupted at coding path "\#(ctx.codingPath.printableString)"."#)
                result.append("\(Self.prefix)\t\(ctx.debugDescription)")
                attachedError = ctx.underlyingError
            @unknown default:
                result.append("Non-identifyiable.")
            }
        // MARK: IG.API.Error
        } else if let error = subError as? IG.API.Error {
            result.append("API error: \(error.type) \(error.message) \(error.suggestion)")
            attachedError = error.underlyingError
        // MARK: IG.Streamer.Error
        } else if let error = subError as? IG.Streamer.Error {
            result.append("Streamer error: \(error.type) \(error.message) \(error.suggestion)")
            attachedError = error.underlyingError
        // MARK: IG.Streamer.Subscription.Error
        } else if let error = subError as? IG.Streamer.Subscription.Error {
            result.append("subscription error (code \(error.code)): \(String(describing: error.type))")
            if let message = error.message {
                result.append("\(Self.prefix)\tMessage: \(message)")
            }
        // MARK: IG.Streamer.Formatter.Update.Error
        } else if let error = subError as? IG.Streamer.Formatter.Update.Error {
            result.append("transformation error:")
            result.append("\(Self.prefix)\tResult type: \(error.type)")
            result.append("\(Self.prefix)\tValue received: \(error.value)")
        // MARK: IG.Database.Error
        } else if let error = subError as? IG.DB.Error {
            result.append("Database error: \(error.type) \(error.message) \(error.suggestion)")
            attachedError = error.underlyingError
        // MARK: Unknown error
        } else {
            result.append("unknown error: ")
            result.append(Self.excerpt(of: subError, maximumCharacters: 100))
        }
        
        if let sourceError = attachedError {
            result.append("\(Self.prefix)\tSource error: \(Self.excerpt(of: sourceError, maximumCharacters: 100))")
        }
        return result
    }
    /// Huamn readable version of the error context.
    internal var printableContext: String? {
        guard !self.context.isEmpty else { return nil }
        
        var result = "\(Self.prefix)Context:"
        for element in self.context {
            result.append("\(Self.prefix)\t* \(element.title): ")
            
            switch element.value {
            case let string as String:
                result.append(string)
            case let update as [String:IG.Streamer.Subscription.Update]:
                result.append("[")
                result.append(update.map { (key, value) in
                    let u = (value.isUpdated) ? "(not updated) " : ""
                    let v = value.value ?? "nil"
                    return "\(key): \(u)\(v)"
                }.joined(separator: ", "))
                result.append("]")
            case let date as Date:
                result.append(self.dateFormatter.string(from: date))
            case let limit as IG.Deal.Limit:
                switch limit.type {
                case .distance(let distance): result.append(#"distance "\#(distance)""#)
                case .position(let level): result.append(#"level "\#(level)""#)
                }
            case let stop as IG.Deal.Stop:
                switch stop.type {
                case .distance(let distance): result.append(#"distance "\#(distance)""#)
                case .position(let level): result.append(#"level "\#(level)""#)
                }
                result.append(", ")
                switch stop.risk {
                case .exposed: result.append("exposed risk")
                case .limited(let premium):
                    result.append("limited risk")
                    if let comission = premium { result.append(#" (premium "\#(comission)""#) }
                }
                switch stop.trailing {
                case .static: break
                case .dynamic(let settings):
                    result.append(", trailing")
                    if let s = settings { result.append(#" distance "\#(s.distance)", increment "\#(s.increment)""#) }
                }
            case let request as URLRequest:
                if let method = request.httpMethod { result.append("\(method) ") }
                if let url = request.url { result.append("\(url) ") }
                if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
                    result.append("\(Self.prefix)\t[")
                    result.append(headers.map { "\($0): \($1)" }.joined(separator: ", "))
                    result.append("]")
                }
            case let statuses as [IG.Streamer.Session.Status]:
                let representation = statuses.map { $0.debugDescription }.joined(separator: ", ")
                result.append("[\(representation)]")
            case let errors as [IG.Streamer.Error]:
                let representation = errors.map { "\($0.type)" }.joined(separator: ", ")
                result.append("[\(representation)]")
            default:
                result.append(Self.excerpt(of: element.value, maximumCharacters: 45))
            }
        }
        return result
    }
    
    /// The date formatter to use when representing dates on errors.
    private var dateFormatter: DateFormatter {
        let result = IG.API.Formatter.humanReadableLong.deepCopy
        result.timeZone = TimeZone.current
        return result
    }
    
    /// Returns a `String` representation of the given instance with a maximum of `max` characters.
    /// - parameter instance: The instance to represent as a `String`.
    /// - parameter max: The maximum amount of characters in the string.
    private static func excerpt(of instance: Any, maximumCharacters max: Int) -> String {
        let string = String(describing: instance)
        let end = string.index(string.startIndex, offsetBy: max, limitedBy: string.endIndex) ?? string.endIndex
        return String(string[..<end])
    }
}

// MARK: - Supporting functionality

extension CodingKey {
    /// Human readable print version of the coding key.
    fileprivate var printableString: String {
        if let number = self.intValue {
            return String(number)
        } else {
            return self.stringValue
        }
    }
}

extension Array where Array.Element == CodingKey {
    fileprivate var printableString: String {
        return self.map { $0.printableString }.joined(separator: "/")
    }
}
