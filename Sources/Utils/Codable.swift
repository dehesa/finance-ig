import Foundation

extension DecodingError: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = ErrorPrint(domain: "Decoding Error")
        
        switch self {
        case .keyNotFound(let key, let ctx):
            result.title = "Key not found."
            result.append(details: "Key: \(key.representation)")
            result.append(details: "Coding path: \(ctx.codingPath.representation)")
            result.append(involved: ctx)
            result.append(error: ctx.underlyingError)
        case .valueNotFound(let type, let ctx):
            result.title = "Value not found."
            result.append(details: "A value of type \"\(type)\" was not found.")
            result.append(details: "Codng path: \(ctx.codingPath.representation)")
            result.append(involved: ctx)
            result.append(error: ctx.underlyingError)
        case .dataCorrupted(let ctx):
            result.title = "Data corrupted."
            result.append(details: "Coding path: \(ctx.codingPath.representation)")
            result.append(involved: ctx)
            result.append(error: ctx.underlyingError)
        case .typeMismatch(let type, let ctx):
            result.title = "Type mismatch."
            result.append(details: "Value found is not of type \"\(type)\".")
            result.append(details: "Coding path: \(ctx.codingPath.representation)")
            result.append(involved: ctx)
            result.append(error: ctx.underlyingError)
        @unknown default:
            result.title = "Non-identified error."
            result.append(involved: self)
        }
        
        return result.debugDescription
    }
}

extension EncodingError: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = ErrorPrint(domain: "Encoding Error")
        
        switch self {
        case .invalidValue(let value, let ctx):
            result.title = "Invalid value."
            result.append(details: "Coding path: \(ctx.codingPath.representation)")
            result.append(involved: value)
            result.append(involved: ctx)
            result.append(error: ctx.underlyingError)
        @unknown default:
            result.title = "Non-identified error."
            result.append(involved: self)        
        }
        
        return result.debugDescription
    }
}

private extension CodingKey {
    var representation: String {
        if let number = self.intValue {
            return String(number)
        } else {
            return self.stringValue
        }
    }
}

private extension Array where Array.Element == CodingKey {
    var representation: String {
        return self.map { $0.representation }.joined(separator: "/")
    }
}
