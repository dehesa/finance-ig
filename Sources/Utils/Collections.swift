
extension Array where Element: Equatable {
    /// Removes the duplicate elements while conserving order.
    internal var uniqueElements: Self {
        return self.reduce(into: Self.init()) { (result, element) in
            guard !result.contains(element) else { return }
            result.append(element)
        }
    }
}
