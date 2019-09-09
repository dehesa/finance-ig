import Foundation

/// The format of the mocked JSON files representing streamer responses.
struct StreamerMockedJSON: Decodable {
    /// All the stream events that the mocked server send along the lifetime of the subscription session.
    let events: [Event]
    
    /// The name of all fields set on updates.
    ///
    /// This property reads all the update events and extract which fields are defined. It gives in a set all field names being set at some point.
    var fields: Set<String> {
        return events.reduce(into: Set<String>()) { (result, event) in
            guard case .update(_, let fields) = event, !fields.isEmpty else { return }
            for key in fields.keys {
                result.insert(key)
            }
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.events = try container.decode([Event].self)
    }
}

extension StreamerMockedJSON {
    /// The type of streamer event.
    enum Event: Decodable {
        case update(isSnapShot: Bool, fields: [String:String])
        case lost
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            switch try container.decodeIfPresent(String.self, forKey: .type) {
            case let type? where type == TypeValue.lost.rawValue:
                self = .lost
            case let type? where type == TypeValue.update.rawValue:
                fallthrough
            case nil:
                let isSnapshot = try container.decodeIfPresent(Bool.self, forKey: .isSnapshot) ?? false
                let fields: [String:String] = try container.decodeIfPresent([String:String].self, forKey: .fields) ?? [:]
                self = .update(isSnapShot: isSnapshot, fields: fields)
            case let type?:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "The event type\"\(type)\" is invalid")
            }
        }
        
        /// Top-level coding-keys for an event JSON object.
        private enum CodingKeys: String, CodingKey {
            case type, isSnapshot, fields
        }
        
        /// Possible values for the `type` coding key.
        private enum TypeValue: String {
            case update, lost
        }
    }
}
