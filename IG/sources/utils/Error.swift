/// Errors thrown by the IG framework.
public protocol Error: Swift.Error {
    /// The error subtype within this errors domain.
    associatedtype Kind: CaseIterable
    /// A type for a context item.
    typealias Item = (title: String, value: Any)
    
    /// The type of error.
    var type: Self.Kind { get }
    /// A message accompaigning the error explaining what happened.
    var message: String { get }
    /// Possible solutions for the problem.
    var suggestion: String { get }
    /// Any underlying error that was raised right before this hosting error.
    var underlyingError: Swift.Error? { get }
    /// Store values/objects that gives context to the hosting error.
    var context: [Item] { get }
}

// MARK: -

/// Definitions conforming to this protocol are used as namespaces for `IG.Error`s, such as messages and suggestions.
internal protocol ErrorNameSpace: RawRepresentable, ExpressibleByStringLiteral where Self.RawValue==String, Self.StringLiteralType==String {
    /// Designated initializer with a pre-validated value.
    /// - parameter trustedValue: The pre-validated raw value.
    init(_ trustedValue: String)
}

extension ErrorNameSpace {
    init(stringLiteral value: String) {
        precondition(!value.isEmpty, "Error strings cannot be empty")
        self.init(value)
    }
    
    init?(rawValue: Self.RawValue) {
        guard !rawValue.isEmpty else { return nil }
        self.init(rawValue)
    }
}
