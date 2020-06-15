import Foundation

internal extension String {
    private static let _lowercaseASCII = "abcdefghijklmnopqrstuvwxyz"
    private static let _uppercaseASCII = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    private static let _numbers = "0123456789"
    
    /// Randomize the letters and numbers of the receiving string, keeping the length of the string.
    var randomize: String {
        guard self.count > 0 else { return "" }
        
        let sets = [Self._lowercaseASCII, Self._uppercaseASCII, Self._numbers]
        let result = self.map { (char) -> Character in
            for set in sets {
                guard set.contains(char) else { continue }
                return set[set.index(set.startIndex, offsetBy: Int.random(in: 0..<set.count))]
            }
            
            return char
        }
        
        return String(result)
    }
    
    static func random(length: Int) -> String {
        let pool = _lowercaseASCII.appending(_uppercaseASCII)
        return .init((0..<length).map { _ in pool.randomElement()! })
    }
}
