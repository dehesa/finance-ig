import Foundation
import Decimals

extension API {
    /// Node within the Broker platform markets organization.
    public struct Node: Identifiable {
        /// Node identifier.
        /// - note: The top of the tree will return `nil` for this property.
        public let id: String?
        /// Node name.
        public var name: String?
        /// The children nodes (subnodes) of `self`
        ///
        /// There can be three possible options:
        /// - `nil`if there hasn't be a query to ask for this node's subnodes.
        /// - Empty array if this node doesn't have any subnode.
        /// - Non-empty array if the node has children.
        public internal(set) var subnodes: [Self]?
        /// The markets organized under `self`
        ///
        /// There can be three possible options:
        /// - `nil`if there hasn't be a query to ask for this node's markets..
        /// - Empty array if this node doesn't have any market..
        /// - Non-empty array if the node has markets..
        public internal(set) var markets: [Self.Market]?
        
        /// First step initializer, providing the data for the node identifier and name.
        internal init(id: String?, name: String?) {
            self.id = id
            self.name = name
            self.subnodes = nil
            self.markets = nil
        }
    }
}

// MARK: -

extension API.Node: Decodable {
    public init(from decoder: Decoder) throws {
        self.id = decoder.userInfo[API.JSON.DecoderKey.nodeIdentifier] as? String
        self.name = decoder.userInfo[API.JSON.DecoderKey.nodeName] as? String
        
        let container = try decoder.container(keyedBy: _Keys.self)
        
        var subnodes: [API.Node] = []
        if container.contains(.nodes), try !container.decodeNil(forKey: .nodes) {
            var array = try container.nestedUnkeyedContainer(forKey: .nodes)
            while !array.isAtEnd {
                let nodeContainer = try array.nestedContainer(keyedBy: _Keys._NestedKeys.self)
                let id = try nodeContainer.decode(String.self, forKey: .id)
                let name = try nodeContainer.decode(String.self, forKey: .name)
                subnodes.append(API.Node(id: id, name: name))
            }
        }
        self.subnodes = subnodes
        
        if container.contains(.markets), try !container.decodeNil(forKey: .markets) {
            self.markets = try container.decode(Array<Self.Market>.self, forKey: .markets)
        } else {
            self.markets = []
        }
    }
    
    private enum _Keys: String, CodingKey {
        case nodes, markets
        
        enum _NestedKeys: String, CodingKey {
            case id, name
        }
    }
}

internal extension API.JSON.DecoderKey {
    /// Key for JSON decoders under which a node identifier will be stored.
    static let nodeIdentifier = CodingUserInfoKey(rawValue: "IG_APINodeId").unsafelyUnwrapped
    /// Key for JSON decoders under which a node name will be stored.
    static let nodeName = CodingUserInfoKey(rawValue: "IG_APINodeName").unsafelyUnwrapped
}
