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

extension Array {
    /// Checks whether the receiving array is sorted following the given predicate.
    /// - parameter areInIncreasingOrder: A predicate that returns `true` if its first argument should be ordered before its second argument; otherwise, `false`.
    internal func isSorted(_ areInIncreasingOrder: (Element,Element) throws ->Bool) rethrows -> Bool {
        var indeces: (previous: Index, current: Index) = (self.startIndex, self.startIndex.advanced(by: 1))

        while indeces.current != self.endIndex {
            guard try areInIncreasingOrder(self[indeces.previous], self[indeces.current]) else {
                return false
            }
            
            indeces = (indeces.current, indeces.current.advanced(by: 1))
        }

        return true
    }
}

extension RangeReplaceableCollection where Index==Int {
    /// Split an array into chunks.
    /// ```swift
    /// let num = Array(1...50)
    /// let chunks = numbers.chunked(into: 10)
    /// ```
    /// - parameter size: The size of each chunk.
    internal func chunked(into size: Int) -> [Self] {
        stride(from: 0, to: self.count, by: size).map {
            Self(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension Set {
    /// Split a set into chunks.
    /// - parameter size: The size of each chunk.
    internal func chunked(into size: Int) -> [Self] {
        var next = self.startIndex
        return stride(from: 0, to: self.count, by: size).map { _ -> Self in
            let start = next
            let end = self.index(next, offsetBy: size, limitedBy: self.endIndex) ?? self.endIndex
            next = end
            
            return Self.init(self[start..<end])
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

extension PartialRangeFrom: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = String(describing: self.lowerBound)
        result.append("...")
        return result
    }
}

extension PartialRangeUpTo: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = "..<"
        result.append(String(describing: self.upperBound))
        return result
    }
}

extension PartialRangeThrough: CustomDebugStringConvertible {
    public var debugDescription: String {
        var result = "..."
        result.append(String(describing: self.upperBound))
        return result
    }
}
