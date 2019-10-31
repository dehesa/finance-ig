import Foundation

/// A range representing the span of time between two dates.
///
/// This range always includes their boundaries, although one of them can be open (never the two at the same time).
struct DateRange: CustomDebugStringConvertible {
    /// The lower bound.
    ///
    /// It can be a given date or `nil` (which represents the beginning of time).
    let from: Date?
    /// The upper bound.
    ///
    /// It can be a given date or `nil` (which represents the end of time).
    let to: Date?
    
    /// Creates an open ended range starting (and including) the given date.
    init(from: Date) {
        self.from = from
        self.to = nil
    }
    
    /// Creates an open ended range ending (and including) the given date.
    init(to: Date) {
        self.from = nil
        self.to = to
    }
    
    /// The close ended range.
    init(from: Date, to: Date) {
        self.from = from
        self.to = to
    }
    
    var debugDescription: String {
        switch (self.from, self.to) {
        case (let from?, let to?): return "\(from) ... \(to)"
        case (let from?, .none): return "\(from) ..."
        case (.none, let to?): return "... \(to)"
        default: fatalError()
        }
    }
    
    /// An error occurred when a time range is being considered.
    enum Error: Swift.Error {
        case invalidInterval(from: Date, to: Date)
        case invalidSorting(from: Date, to: Date)
        case repeteadPrice(date: Date)
    }
}

extension Array where Element==Date {
    /// Returns `DateRange`s indicating the timeframes not included in the receiving array.
    ///
    /// This function considers that elements are contiguous in time when they are exactly one minute apart.
    /// - precondition: The array must be already sorted before this function is called or an error will be thrown.
    func missingDateRanges() throws -> [DateRange] {
        var result: [DateRange] = []
        guard !self.isEmpty else { return result }
        
        let calendar = Calendar(identifier: .iso8601)
        result.append( .init(to: calendar.date(byAdding: .minute, value: -1, to: self[0])!) )
        
        if self.count > 1 {
            var previous = self[0]
            for date in self[1..<self.endIndex] {
                let seconds = Int(date.timeIntervalSince(previous))
                if seconds == 60 {
                    previous = date
                } else if seconds > 60 {
                    let from = calendar.date(byAdding: .minute, value: 1, to: previous)!
                    let to = calendar.date(byAdding: .minute, value: -1, to: date)!
                    guard Int(to.timeIntervalSince(from)) % 60 == 0 else {
                        throw DateRange.Error.invalidInterval(from: previous, to: date)
                    }
                    result.append(.init(from: from, to: to))
                    previous = date
                } else if seconds == 0 {
                    throw DateRange.Error.repeteadPrice(date: date)
                } else if seconds < 0 {
                    throw DateRange.Error.invalidSorting(from: previous, to: date)
                } else {
                    throw DateRange.Error.invalidInterval(from: previous, to: date)
                }
            }
        }
        
        result.append( .init(from: calendar.date(byAdding: .minute, value: 1, to: self.last!)!) )
        return result
    }
}
