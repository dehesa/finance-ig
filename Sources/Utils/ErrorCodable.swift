import Foundation

extension Swift.EncodingError: IG.ErrorPrintable {
    internal static var printableDomain: String {
        return "Swift.\(EncodingError.self)"
    }
    
    internal var printableType: String {
        switch self {
        case .invalidValue: return "Invalid value"
        @unknown default:   return "Unknown, not yet supported"
        }
    }
    
    internal func printableMultiline(level: Int) -> String {
        let levelPrefix = Self.debugPrefix(level: level+1)
        var result = "\(Self.printableDomain) (\(self.printableType))"
        
        switch self {
        case .invalidValue(let val, let ctx):
            if !ctx.codingPath.isEmpty {
                result.append("\(levelPrefix)Coding path: \(ctx.codingPath.printableString)")
            }
            result.append("\(levelPrefix)Message: \(ctx.debugDescription)")
            
            let valueStr = "\(levelPrefix)Encoding value: "
            result.append(valueStr)
            result.append(IG.ErrorHelper.representation(of: val, prefixCount: valueStr.count, maxCharacters: Self.maxCharsPerLine))
            
            let errorStr = "\(levelPrefix)Underlying error: "
            if let errorRepresentation = IG.ErrorHelper.representation(of: ctx.underlyingError, level: level, prefixCount: errorStr.count, maxCharacters: Self.maxCharsPerLine) {
                result.append(errorStr)
                result.append(errorRepresentation)
            }
        @unknown default:
            break
        }
        
        return result
    }
}

extension Swift.DecodingError: IG.ErrorPrintable, CustomDebugStringConvertible {
    internal static var printableDomain: String {
        return "Swift.\(DecodingError.self)"
    }
    
    internal var printableType: String {
        switch self {
        case .keyNotFound:   return "Key not found"
        case .valueNotFound: return "Value not found"
        case .typeMismatch:  return "Type mismatch"
        case .dataCorrupted: return "Data corrupted"
        @unknown default:    return "Unknown, not yet supported"
        }
    }
    
    internal func printableMultiline(level: Int) -> String {
        let levelPrefix = Self.debugPrefix(level: level+1)
        var result = "\(Self.printableDomain) (\(self.printableType))"
        let context: DecodingError.Context
        switch self {
        case .keyNotFound(let key, let ctx):
            result.append("\(levelPrefix)Key: \(key.printableString)")
            context = ctx
        case .valueNotFound(let type, let ctx):
            result.append("\(levelPrefix)Type: \(type)")
            context = ctx
        case .typeMismatch(let type, let ctx):
            result.append("\(levelPrefix)Type: \(type)")
            context = ctx
        case .dataCorrupted(let ctx):
            context = ctx
        @unknown default:
            return result
        }
        
        if !context.codingPath.isEmpty {
            result.append("\(levelPrefix)Coding path: \(context.codingPath.printableString)" )
        }
        result.append("\(levelPrefix)Message: \(context.debugDescription)")
        
        let errorStr = "\(levelPrefix)Underlying error: "
        if let errorRepresentation = IG.ErrorHelper.representation(of: context.underlyingError, level: level, prefixCount: errorStr.count, maxCharacters: Self.maxCharsPerLine) {
            result.append(errorStr)
            result.append(errorRepresentation)
        }
        
        return result
    }
}

// MARK: - Supporting functionality

extension Swift.CodingKey {
    /// Human readable print version of the coding key.
    fileprivate var printableString: String {
        if let number = self.intValue {
            return String(number)
        } else {
            return self.stringValue
        }
    }
}

extension Array where Array.Element == Swift.CodingKey {
    fileprivate var printableString: String {
        return self.map { $0.printableString }.joined(separator: "/")
    }
}
