extension String {
    /// Randomize the letters and numbers of the receiving string, keeping the length of the string.
    internal var randomize: String {
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
}
