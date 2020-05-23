internal extension Set where Element==Character {
    /// Lowercase ANSI letters (from `a` to `z`).
    static let lowercaseANSI = Self( (Unicode.Scalar("a").value...Unicode.Scalar("z").value).map { Character(Unicode.Scalar($0)!) } )
    /// Uppercase ANSI letters (from `a` to `z`).
    static let uppercaseANSI = Self( (Unicode.Scalar("A").value...Unicode.Scalar("Z").value).map { Character(Unicode.Scalar($0)!) } )
    /// Returns a character set containing the characters in the category of Decimal Numbers.
    static let decimalDigits = Self( (Unicode.Scalar("0").value...Unicode.Scalar("9").value).map { Character(Unicode.Scalar($0)!) } )
}
