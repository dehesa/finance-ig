import Foundation

extension String {
    private static let lowercaseASCII = "abcdefghijklmnopqrstuvwxyz"
    private static let uppercaseASCII = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    private static let numbers = "0123456789"
    
    /// Randomize the letters and numbers of the receiving string, keeping the length of the string.
    internal var randomize: String {
        guard self.count > 0 else { return "" }
        
        let sets = [Self.lowercaseASCII, Self.uppercaseASCII, Self.numbers]
        let result = self.map { (char) -> Character in
            for set in sets {
                guard set.contains(char) else { continue }
                return set[set.index(set.startIndex, offsetBy: Int.random(in: 0..<set.count))]
            }
            
            return char
        }
        
        return String(result)
    }
    
    internal static func random(length: Int) -> String {
        let pool = lowercaseASCII.appending(uppercaseASCII)
        return .init((0..<length).map { _ in pool.randomElement()! })
    }
}
