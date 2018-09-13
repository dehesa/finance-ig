/// An epic represents a unique tradeable market.
public protocol Epic {
    /// Unique identifier through the IG platform.
    var identifier: String { get }
}

extension Array where Element == Epic {
    /// Checks that the array of Epics are unique and there is at least one epic.
    /// - returns: Boolean indicating whether the array has at least one value and those values are unique.
    var isUniquelyLaden: Bool {
        guard !self.isEmpty else { return false }
        
        var set = Set<String>(minimumCapacity: self.count)
        for epic in self {
            let identifier = epic.identifier
            guard !identifier.isEmpty,
                  set.insert(identifier).inserted else { return false }
        }
        
        return set.count == self.count
    }
}

extension Array where Element: Hashable {
    /// Checks that the array of elements are unique and there is at least one value.
    /// - returns: Boolean indicating whether the array has at least one value and those values are unique.
    var isUniquelyLaden: Bool {
        return !self.isEmpty && Set(self).count == self.count
    }
}

/// List of all tradable markets.
public enum Market {
    /// Foreign exchange related markets.
    public enum Forex {}
}
