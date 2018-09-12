import Foundation

/// A response from one streamer subscription.
public protocol StreamerResponse: CustomDebugStringConvertible {
    /// The field type for this response.
    associatedtype Field: StreamerField
    /// An update structure given meta information of this response.
    typealias Update = Streamer.Response.Update<Field>
    
    /// Indicate the fields/properties that contain values and which one has seen value chages from the last update.
    var fields: Self.Update { get }
}

extension Streamer.Response {
    /// Structure containing metadata information for a receiving response.
    public struct Update<Field:StreamerField> {
        /// The fields/properties that contain values.
        public let received: Set<Field>
        /// The fields/properties that have seen its value changed since the last update was received.
        public let delta: Set<Field>
        
        /// Pass-through initializer.
        internal init(received: Set<Field>, delta: Set<Field>) {
            self.received = received
            self.delta = delta
        }
    }
}

extension StreamerResponse where Field: StreamerFieldKeyable, Field.Response == Self {
    /// A dictionary containing all the set values in the response.
    var values: [Field:Any?] {
        let received = self.fields.received
        
        var result = Dictionary<Field,Any>(minimumCapacity: received.count)
        for key in received {
            result[key] = self[keyPath: key.keyPath]
        }
        return result
    }
    
    public var debugDescription: String {
        let fields = self.values.map {
            return "\t\($0): \($1 ?? "nil")"
            }.sorted().joined(separator: "\n")
        
        return "\(type(of: self)) {\n" + fields + "\n}"
    }
}
