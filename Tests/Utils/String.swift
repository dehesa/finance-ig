extension String {
    /// Randomize the letters and numbers of the receiving string, keeping the length of the string.
    var randomize: String {
        guard self.count > 0 else { return "" }
        
        let sets = ["abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "0123456789"]
        let result = self.map { (char) -> Character in
            for set in sets {
                guard set.contains(char) else { continue }
                return set[set.index(set.startIndex, offsetBy: Int.random(in: 0..<set.count))]
            }
            
            return char
        }
        
        return String(result)
    }
    
    /// Print the receiving string, but only in the character range passed as parameter.
    /// - parameter range: The range of characters to be printed.
    func debugPrint(between range: ClosedRange<Int>) {
        guard range.lowerBound > 0, range.upperBound >= range.upperBound else { fatalError("Invalid range: \(range)") }
        let start = self.index(self.startIndex, offsetBy: range.lowerBound)
        let stop = self.index(self.startIndex, offsetBy: range.upperBound)
        print(self[start..<stop])
    }
}
