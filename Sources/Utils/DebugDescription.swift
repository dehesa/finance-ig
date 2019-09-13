import Foundation

/// Used on types with a custom debug descriptions within this framework.
internal protocol DebugDescriptable: CustomDebugStringConvertible {
    /// The name to use as the receiver domain.
    static var printableDomain: String { get }
}

/// Convenience structure gathering several items in a final `String` representation.
///
/// Here is an example of an outcome for this structure with the default settings:
/// ```
/// API.Application
///     key: a12345bc67890d12345e6789fg0hi123j4567890
///     name: custom_name
///     status: ENABLED
///     permission:
///         access to equities: ✔︎
///         quote orders allowed: ✘
///     allowance:
///         overall requests: 60
///         account:
///             overall requests: 30
///             trading requests: 100
///             price requests: 10000
///         concurrent subscription limit: 40
///     creation: 2019.02.28
/// ```
internal struct DebugDescription {
    /// Gathers the result so far.
    private var result: String
    /// The divider between each line.
    let lineSeparator: String
    /// The "spacer" indicating one level.
    let levelMarker: String
    /// The separation between a name and a value (e.g. `": "`)
    let itemDelimiter: String
    /// The value appended at the end when the final string has been generated (e.g. `"}"`)
    let stop: String?
    /// It controls the "inheritance" level.
    private(set) var level: Int
    
    /// List of symbols supported by default.
    enum Symbol {
        static let `nil` = "␣"
        static let `true` = "✔︎"
        static let `false` = "✘"
        static let arraySeparator = ", "
    }
    
    /// Designated initializer specifying how the generated string will be printed out.
    /// - parameter start: The first line of the generated result.
    /// - parameter line: The line separator characters.
    /// - parameter spacer: The space between levels.
    /// - parameter item: The name-to-description separator.
    /// - parameter ends: The last line of the generated result.
    init(_ start: String?, line: String = "\n", spacer: String = "\t", item: String = ": ", ends: String? = nil) {
        if let start = start {
            self.result = start
            self.result.append(line)
            self.level = 1
        } else {
            self.result = String()
            self.level = 0
        }
        self.lineSeparator = line
        self.levelMarker = spacer
        self.itemDelimiter = item
        self.stop = ends
    }
    
    /// Appends the given name, an item delimiter, a Boolean value to the `String` representation, and a line separator.
    /// - parameter name: The beginning of the description line (the text before the `itemDelimiter`).
    /// - parameter value: A Boolean value that will be represented after the `itemDelimiter`. If `nil`, a symbol representing an empty value will be generated.
    mutating func append(_ name: String, _ value: Bool?) {
        guard let boolean = value else {
            return self.append(name, Self.Symbol.nil)
        }
        self.append(name, (boolean) ? Self.Symbol.true: Self.Symbol.false)
    }
    
    /// Appends the given name, an item delimiter, a `String` value to the `String` representation, and a line separator.
    ///
    /// This method does the major heavy-lifting.
    /// - parameter name: The beginning of the description line (the text before the `itemDelimiter`).
    /// - parameter value: A String value that will be represented after the `itemDelimiter`.
    mutating func append(_ name: String, _ value: String) {
        self.result.append(String(repeating: self.levelMarker, count: self.level))
        self.result.append(name)
        self.result.append(self.itemDelimiter)
        self.result.append(value)
        self.result.append(self.lineSeparator)
    }
    
    /// Appends the given name, an item delimiter, a `String` value to the `String` representation, and a line separator.
    ///
    /// This method does the major heavy-lifting.
    /// - parameter name: The beginning of the description line (the text before the `itemDelimiter`).
    /// - parameter value: A String value that will be represented after the `itemDelimiter`. If `nil`, a symbol representing an empty value will be generated.
    mutating func append(_ name: String, _ value: String?) {
        self.append(name, value ?? Self.Symbol.nil)
    }
    
    /// Appends the given name, an item delimiter, a `String`'s `RawRepresentable` value to the `String` representation, and a line separator.
    /// - parameter name: The beginning of the description line (the text before the `itemDelimiter`).
    /// - parameter value: A `RawRepresentable` value that will be represented after the `itemDelimiter`. If `nil`, a symbol representing an empty value will be generated.
    mutating func append<T>(_ name: String, _ value: T?) where T:RawRepresentable, T.RawValue == String {
        guard let representable = value else {
            return self.append(name, Self.Symbol.nil)
        }
        
        self.append(name, representable.rawValue)
    }
    
    /// Appends the given name, an item delimiter, a numeric value to the `String` representation, and a line separator.
    /// - parameter name: The beginning of the description line (the text before the `itemDelimiter`).
    /// - parameter value: A `Numeric` value that will be represented after the `itemDelimiter`. If `nil`, a symbol representing an empty value will be generated.
    mutating func append<T>(_ name: String, _ value: T?) where T:Numeric {
        guard let number = value else {
            return self.append(name, Self.Symbol.nil)
        }
        
        self.append(name, String(describing: number))
    }
    
    /// Appends the given name, an item delimiter, a `Date` value to the `String` representation, and a line separator.
    /// - parameter name: The beginning of the description line (the text before the `itemDelimiter`).
    /// - parameter value: A `Date` value that will be represented after the `itemDelimiter`. If `nil`, a symbol representing an empty value will be generated.
    /// - parameter formatter: The `DateFormatter` used to transform the value into a string.
    mutating func append(_ name: String, _ value: Date?, formatter: DateFormatter) {
        guard let date = value else {
            return self.append(name, Self.Symbol.nil)
        }
        
        var result = formatter.string(from: date)
        
        if let timeZone = formatter.timeZone {
            let abbreviation: String
            if timeZone == .current {
                abbreviation = timeZone.abbreviation(for: date) ?? "local"
            } else if timeZone == IG.UTC.timezone {
                abbreviation = "UTC"
            } else if timeZone.identifier == "Europe/London" {
                if let suffix = timeZone.abbreviation(for: date) {
                    abbreviation = "London \(suffix)"
                } else {
                    abbreviation = "London"
                }
            }else {
                abbreviation = timeZone.abbreviation(for: date) ?? timeZone.identifier
            }
            result.append(" (\(abbreviation))")
        }
        
        self.append(name, result)
    }
    
    /// Appends the given name, an item delimiter, an array of `String`s, and a line separator.
    /// - parameter name: The beginning of the description line (the text before the `itemDelimiter`).
    /// - parameter value: An array of `String`s that will be "coalesced" together in a single line after the `itemDelimiter`. If `nil`, a symbol representing an empty value will be generated.
    mutating func append(_ name: String, _ value: [String]?) {
        guard let array = value else {
            return self.append(name, Self.Symbol.nil)
        }
        
        var representation = "["
        representation.append(array.joined(separator: Self.Symbol.arraySeparator))
        representation.append("]")
        self.append(name, representation)
    }
    
    /// Appends the given name, an item delimiter, an array of `RawRepresentable`s, and a line separator.
    /// - parameter name: The beginning of the description line (the text before the `itemDelimiter`).
    /// - parameter value: An array of `RawRepresentable`s that will be "coalesced" together in a single line after the `itemDelimiter`. If `nil`, a symbol representing an empty value will be generated.
    mutating func append<T>(_ name: String, _ value: [T]?) where T:RawRepresentable, T.RawValue == String {
        self.append(name, value?.map { $0.rawValue })
    }
    
    /// Appends the given name, an item delimiter, and a new child hierarchy to the `String` representation.
    /// - parameter name: The beginning of the description line (the text before the `itemDelimiter`).
    /// - parameter delimiter: Boolean indicating whether the line should include the `itemDelimiter` between the name and the given object/structure value.
    /// - parameter value: A value that should be represented in several lines.
    /// - parameter childrenPrefix: Characters to be included after the name (and possibly the `itemDelimiter`).
    /// - parameter childrenPostfix: Characters to be included after all children have been printed. The characters will be contained in a new line.
    /// - parameter children: Closure printing all lines of the `value`. The lines will be marked a having a +1 level.
    mutating func append<T>(_ name: String, delimiter: Bool = true, _ value: T?, prefix childrenPrefix: String? = nil, postfix childrenPostfix: String? = nil, _ children: (inout Self,T)->Void) {
        self.result.append(String(repeating: self.levelMarker, count: self.level))
        self.result.append(name)
        if delimiter {
            self.result.append(self.itemDelimiter)
        }
        
        guard let value = value else {
            self.result.append(Self.Symbol.nil)
            return self.result.append(self.lineSeparator)
        }
        
        if let prefix = childrenPrefix {
            self.result.append(prefix)
        }
        self.result.append(self.lineSeparator)
        
        self.level += 1
        children(&self,value)
        self.level -= 1
        
        if let postfix = childrenPostfix {
            self.result.append(String(repeating: self.levelMarker, count: self.level))
            self.result.append(postfix)
            self.result.append(self.lineSeparator)
        }
    }
    
    /// Returns the complete description.
    ///
    /// It basically append at the end of the string the final characters given in the initializer.
    func generate() -> String {
        guard let stop = self.stop else {
            return self.result
        }
        
        var result = self.result
        result.append(self.lineSeparator)
        result.append(stop)
        return result
    }
}
