
extension Array where Element: Equatable {
    /// Removes the duplicate elements while conserving order.
    internal var uniqueElements: Self {
        return self.reduce(into: Self.init()) { (result, element) in
            guard !result.contains(element) else { return }
            result.append(element)
        }
    }
}

extension CharacterSet {
    /// The custom `CharacterSet`s used by this framework.
    internal enum IG {
        /// Lowercase ANSI letters `a` to `z`.
        static let lowercaseANSI = CharacterSet(charactersIn: "a"..."z")
        /// Uppercase ANSI letters `A` to `Z`.
        static let uppercaseANSI = CharacterSet(charactersIn: "A"..."Z")
    }
}
