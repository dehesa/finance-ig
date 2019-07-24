import Foundation

extension CharacterSet {
    /// The custom `CharacterSet`s used by this framework.
    internal enum Framework {
        /// Lowercase ANSI letters `a` to `z`.
        static let lowercaseANSI = CharacterSet(charactersIn: "a"..."z")
        /// Uppercase ANSI letters `A` to `Z`.
        static let uppercaseANSI = CharacterSet(charactersIn: "A"..."Z")
    }
}
