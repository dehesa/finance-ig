extension Array {
    /// Split an array into chunks.
    ///
    /// ```swift
    /// let numbers = Array(1...100)
    /// let results = numbers.chunked(into: 5)
    /// ```
    /// - author: Paul Hudson
    /// - seealso: [Hacking with Swift post](https://www.hackingwithswift.com/example-code/language/how-to-split-an-array-into-chunks).
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
