import Foundation

/// Convenience structure gathering several items in a final `String` representation.
///
/// Here is an example of an outcome for this structure with the default settings:
/// ```
/// API Application
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
    
    static let nilSymbol = "␣"
    static let trueSymbol = "✔︎"
    static let falseSymbol = "✘"
    static let arrayElementSeparator = ", "
    
    /// Designated initializer specifying how the generated string will be printed out.
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
    mutating func append(_ name: String, _ value: Bool?) {
        guard let boolean = value else {
            return self.append(name, Self.nilSymbol)
        }
        self.append(name, (boolean) ? Self.trueSymbol: Self.falseSymbol)
    }
    
    /// Appends the given name, an item delimiter, a `String` value to the `String` representation, and a line separator.
    ///
    /// This method does the major heavy-lifting.
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
    mutating func append(_ name: String, _ value: String?) {
        self.append(name, value ?? Self.nilSymbol)
    }
    
    /// Appends the given name, an item delimiter, a `String`'s `RawRepresentable` value to the `String` representation, and a line separator.
    mutating func append<T>(_ name: String, _ value: T?) where T:RawRepresentable, T.RawValue == String {
        guard let representable = value else {
            return self.append(name, Self.nilSymbol)
        }
        
        self.append(name, representable.rawValue)
    }
    
    /// Appends the given name, an item delimiter, a numeric value to the `String` representation, and a line separator.
    mutating func append<T>(_ name: String, _ value: T?) where T:Numeric {
        guard let number = value else {
            return self.append(name, Self.nilSymbol)
        }
        
        self.append(name, String(describing: number))
    }
    
    /// Appends the given name, an item delimiter, a `Date` value to the `String` representation, and a line separator.
    mutating func append(_ name: String, _ value: Date?, formatter: DateFormatter) {
        guard let date = value else {
            return self.append(name, Self.nilSymbol)
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
    mutating func append(_ name: String, _ value: [String]?) {
        guard let array = value else {
            return self.append(name, Self.nilSymbol)
        }
        
        var representation = "["
        representation.append(array.joined(separator: Self.arrayElementSeparator))
        representation.append("]")
        self.append(name, representation)
    }
    
    /// Appends the given name, an item delimiter, an array of `RawRepresentable`s, and a line separator.
    mutating func append<T>(_ name: String, _ value: [T]?) where T:RawRepresentable, T.RawValue == String {
        self.append(name, value?.map { $0.rawValue })
    }
    
    /// Appends the given name, an item delimiter, and a new child hierarchy to the `String` representation.
    mutating func append<T>(_ name: String, delimiter: Bool = true, _ value: T?, prefix childrenPrefix: String? = nil, postfix childrenPostfix: String? = nil, _ children: (inout Self,T)->Void) {
        self.result.append(String(repeating: self.levelMarker, count: self.level))
        self.result.append(name)
        if delimiter {
            self.result.append(self.itemDelimiter)
        }
        
        guard let value = value else {
            self.result.append(Self.nilSymbol)
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
