/// Wrapper for an error representation.
internal struct ErrorPrint: CustomDebugStringConvertible {
    var domain: String
    var title: String = ""
    var details: [String] = []
    var involved: [Any] = []
    
    init(domain: String) {
        self.domain = domain
    }
    
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
    
    mutating func append(details: String?) {
        guard let details = details else { return }
        self.details.append(details)
    }
    
    mutating func append(error: Swift.Error?) {
        guard let error = error else { return }
        self.details.append("\(error)")
    }
    
    mutating func append<C:Collection>(involved: C?) {
        guard let involved = involved, !involved.isEmpty else { return }
        self.involved.append(involved)
    }
    
    mutating func append(involved: Any?) {
        guard let involved = involved else { return }
        self.involved.append(involved)
    }
}
