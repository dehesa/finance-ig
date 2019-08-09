import Foundation

/// Errors thrown by this framework follow this protocol.
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

extension Error where Self: ErrorPrintable {
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
        var result = "\(Self.prefix)Underlying "
        var underlyingError: Swift.Error? = nil
        
        guard let error = self.underlyingError else { return nil }
        
        if let encodingError = error as? EncodingError {
            result.append("encoding error: ")
            switch encodingError {
            case .invalidValue(let value, let ctx):
                result.append(#"Invalid value at coding path "\#(ctx.codingPath.printable)"."#)
                result.append("\(Self.prefix)\t\(ctx.debugDescription)")
                result.append("\(Self.prefix)\t\(String(describing: value))")
                underlyingError = ctx.underlyingError
            @unknown default:
                result.append("Non-identifyiable.")
            }
        } else if let decodingError = error as? DecodingError {
            result.append("decoding error: ")
            switch decodingError {
            case .keyNotFound(let key, let ctx):
                result.append(#"Key "\#(key.printable)" not found at coding path "\#(ctx.codingPath.printable)"."#)
                result.append("\(Self.prefix)\t\(ctx.debugDescription)")
                underlyingError = ctx.underlyingError
            case .valueNotFound(let type, let ctx):
                result.append(#"Value of type "\#(type.self)" not found at coding path "\#(ctx.codingPath.printable)"."#)
                result.append("\(Self.prefix)\t\(ctx.debugDescription)")
                underlyingError = ctx.underlyingError
            case .typeMismatch(let type, let ctx):
                result.append(#"Mismatch of expected value type "\#(type.self)" at coding path "\#(ctx.codingPath.printable)"."#)
                result.append("\(Self.prefix)\t\(ctx.debugDescription)")
                underlyingError = ctx.underlyingError
            case .dataCorrupted(let ctx):
                result.append(#"Data corrupted at coding path "\#(ctx.codingPath.printable)"."#)
                result.append("\(Self.prefix)\t\(ctx.debugDescription)")
                underlyingError = ctx.underlyingError
            @unknown default:
                result.append("Non-identifyiable.")
            }
        } else {
            #warning("Implement underlying error representation")
            fatalError()
        }
        
        if let suberror = underlyingError {
            result.append("\(Self.prefix)\tUnderlying \(suberror.self) error: )")
            
            let string = String(describing: suberror)
            let end = string.index(string.startIndex, offsetBy: 50, limitedBy: string.endIndex) ?? string.endIndex
            result.append(String(string[..<end]))
        }
        return result
    }
    /// Huamn readable version of the error context.
    internal var printableContext: String? {
        #warning("Implement context representation")
        fatalError()
    }
}

// MARK: - Supporting functionality

extension CodingKey {
    /// Human readable print version of the coding key.
    fileprivate var printable: String {
        if let number = self.intValue {
            return String(number)
        } else {
            return self.stringValue
        }
    }
}

extension Array where Array.Element == CodingKey {
    fileprivate var printable: String {
        return self.map { $0.printable }.joined(separator: "/")
    }
}
