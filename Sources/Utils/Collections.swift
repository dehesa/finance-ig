import Foundation

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
    /// Lowercase ANSI letters `a` to `z`.
    internal static let lowercaseANSI = CharacterSet(charactersIn: "a"..."z")
    /// The custom `CharacterSet`s used by this framework.
    /// Uppercase ANSI letters `A` to `Z`.
    internal static let uppercaseANSI = CharacterSet(charactersIn: "A"..."Z")
}
