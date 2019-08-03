/// Wrapper for an error representation.
internal struct ErrorPrint {
    /// Two, three, or four words title of where the error happened.
    let domain: String
    /// Brief title description of the error.
    var title: String
    /// Several line details on what happenend.
    private(set) var details: [String] = []
    /// Any value/class instances involved on the error.
    private(set) var involved: [Any] = []
    
    /// Designated initializer giving the error domain.
    /// - parameter domain: Two, three, or four words explaining where the error has happened.
    /// - parameter title: Error title explain in one line of text what has happenend.
    init(domain: String, title: String = "") {
        self.domain = domain
        self.title = title
    }
    /// Appends a new description line (if any) to the error details.
    ///
    /// This function won't perform any operation if `details` is nil or an empty string.
    /// - parameter details: The new line giving further details about the error.
    mutating func append(details: String?) {
        guard let details = details, !details.isEmpty else { return }
        self.details.append(details)
    }
    /// Transforms the error into a `String` and appends it to the receiving error details.
    ///
    /// This function won't perform any operation if `underlyingError` is `nil`.
    /// - parameter underlyingError: An error associated with the receiving error.
    mutating func append(underlyingError: Swift.Error?) {
        guard let error = underlyingError else { return }
        self.details.append("\(error)")
    }
    /// Associates all the object within the given collection with the receiving error.
    ///
    /// This function won't perform any operation if `involved` is `nil` or an empty collection.
    /// - parameter involved: Objects involved on the receiving error's occurrance.
    mutating func append<C:Collection>(involved: C?) {
        guard let involved = involved, !involved.isEmpty else { return }
        self.involved.append(involved)
    }
    /// Associates the given object with the the receiving error.
    ///
    /// This function won't perform any operation if `involved` is `nil`.
    /// - parameter involved: Object "involved" on the receiving error's occurrance.
    mutating func append(involved: Any?) {
        guard let involved = involved else { return }
        self.involved.append(involved)
    }
}

extension ErrorPrint: CustomDebugStringConvertible {
    var debugDescription: String {
        var result = "\n\n[\(self.domain)] \(self.title)"
        for detail in details {
            result.append("\n\t")
            result.append(detail)
        }
        result.append("\n\n")
        guard !self.involved.isEmpty else { return result }
        
        for target in self.involved {
            result.append("\n\n\(target)")
        }
        result.append("\n\n")
        return result
    }
}
