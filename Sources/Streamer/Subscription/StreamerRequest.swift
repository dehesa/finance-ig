import Foundation

/// A possible field/property to select in a streaming response.
public protocol StreamerField: Hashable & RawRepresentable where RawValue == String {}

/// A field that can target where in the response its field value will be.
public protocol StreamerFieldKeyable: StreamerField {
    /// The type of the response where this field will be embedded into.
    associatedtype Response
    /// A parital keypath pointing to this field value in the response type.
    var keyPath: PartialKeyPath<Response> { get }
}



/// Provides the item name for a streamer request.
internal protocol StreamerRequestItemNameable {
    /// The item name from a market's epic.
    /// - parameter epic: The epic name identifying the market.
    static func itemName(identifier: String) -> String
}

/// To form the item name the definition of a prefix is necessary.
internal protocol StreamerRequestItemNamePrefixable: StreamerRequestItemNameable {
    /// The prefix used before the market name on the item name.
    static var prefix: String { get }
}

/// To form a request's item name, the definition of a postfix is necessary.
internal protocol StreamerRequestItemNamePrePostFixable: StreamerRequestItemNamePrefixable {
    /// The postfix used after the market name on the item name.
    static var postfix: String { get }
}

extension StreamerRequestItemNamePrefixable {
    internal static func itemName(identifier: String) -> String {
        return self.prefix + identifier
    }
}

extension StreamerRequestItemNamePrePostFixable {
    internal static func itemName(epic: Epic) -> String {
        return self.prefix + epic.identifier + postfix
    }
}



/// An epic can be inferred from an item name.
internal protocol StreamerRequestItemNameEpicable {
    /// The epic name identifying a market extracted from an item name.
    /// - parameter itemName: The item name.
    static func epic(itemName: String, requestedEpics epics: [Epic]) -> Epic?
}

extension StreamerRequestItemNameEpicable where Self: StreamerRequestItemNamePrefixable {
    internal static func epic(itemName: String, requestedEpics epics: [Epic]) -> Epic? {
        guard itemName.hasPrefix(self.prefix) else { return nil }
        let identifier = String(itemName.dropFirst(self.prefix.count))
        return epics.first { $0.identifier == identifier }
    }
}

extension StreamerRequestItemNameEpicable where Self: StreamerRequestItemNamePrePostFixable {
    internal static func epic(itemName: String, requestedEpics epics: [Epic]) -> Epic? {
        guard itemName.hasPrefix(self.prefix), itemName.hasSuffix(self.postfix) else { return nil }
        let identifier = String(itemName.dropLast(self.postfix.count).dropFirst(self.prefix.count))
        return epics.first { $0.identifier == identifier }
    }
}
