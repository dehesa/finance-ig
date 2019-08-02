
extension String {
    /// Convenience function to append different values to a receiving `String`. If `value` is `nil`, no operation is performed.
    ///
    /// Heavily used during debug printing on `Streamer`.
    /// ```
    /// var debugDescription: String {
    ///     var result: String = self.epic.rawValue
    ///     result.append(prefix: "\n\t", name: "Status", ": ", value: self.status)
    ///     result.append(prefix: "\n\t", name: "Date", ": ", value: self.date.map { Streamer.Formatter.time.string(from: $0) })
    ///     return result
    /// }
    /// ```
    internal mutating func append<T>(prefix: String, name: String, _ separator: String, value: T?) {
        guard let value = value else { return }
        self.append(prefix)
        self.append(name)
        self.append(separator)
        self.append(String(describing: value))
    }
}
