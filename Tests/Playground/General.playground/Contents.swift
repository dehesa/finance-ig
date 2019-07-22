import Foundation

let json = """
{
  "nodes": [
    {
      "id": "668394",
      "name": "Cryptocurrency"
    },
    {
      "id": "99579647",
      "name": "Shares - Euronext Dublin (Ireland)"
    },
    {
      "id": "5371876",
      "name": "Weekend Indices"
    },
    {
      "id": "97601",
      "name": "Indices"
    },
    {
      "id": "264176",
      "name": "Indices (mini)"
    },
    {
      "id": "195235",
      "name": "Forex"
    },
    {
      "id": "264139",
      "name": "Forex (mini)"
    },
    {
      "id": "101515",
      "name": "Commodities Metals Energies"
    },
    {
      "id": "264151",
      "name": "Commodities Metals Energies (mini)"
    },
    {
      "id": "108092",
      "name": "Bonds and Moneymarket"
    },
    {
      "id": "264251",
      "name": "Bonds and Moneymarket (mini)"
    },
    {
      "id": "184730",
      "name": "ETFs, ETCs & Trackers"
    },
    {
      "id": "172904",
      "name": "Shares - LSE (UK)"
    },
    {
      "id": "177223",
      "name": "Shares - NYSE (US)"
    },
    {
      "id": "171438",
      "name": "Shares - XETRA (Germany)"
    },
    {
      "id": "169656",
      "name": "Shares - Euronext (France)"
    },
    {
      "id": "170471",
      "name": "Shares - JSE (South Africa)"
    },
    {
      "id": "170023",
      "name": "Shares - Euronext (Netherlands)"
    },
    {
      "id": "169329",
      "name": "Shares - Euronext (Belgium)"
    },
    {
      "id": "169591",
      "name": "Shares - Euronext (Portugal)"
    },
    {
      "id": "170630",
      "name": "Shares - MIB (Italy)"
    }
  ],
  "markets": null
}
"""

let data = Data(json.utf8)
let key = CodingUserInfoKey(rawValue: "nodeId")!

public struct Node: Decodable {
    /// Node identifier.
    /// - note: The top of the tree will return `nil` for this property.
    public let identifier: String?
    /// Node name.
    public var name: String?
    /// The children nodes (subnodes) of `self`.
    public internal(set) var subnodes: [Node] = []
    /// The markets organized under `self`
    //        public internal(set) var markets: [API.Market] = []
    
    private init(identifier: String, name: String) {
        self.identifier = identifier
        self.name = name
    }
    
    public init(from decoder: Decoder) throws {
        self.identifier = decoder.userInfo[key] as? String
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if container.contains(.nodes), try !container.decodeNil(forKey: .nodes) {
            var array = try container.nestedUnkeyedContainer(forKey: .nodes)
            while !array.isAtEnd {
                let nodeContainer = try array.nestedContainer(keyedBy: CodingKeys.ChildKeys.self)
                let id = try nodeContainer.decode(String.self, forKey: .id)
                let name = try nodeContainer.decode(String.self, forKey: .name)
                self.subnodes.append(.init(identifier: id, name: name))
            }
        }
        
//        if container.contains(.markets), try !container.decodeNil(forKey: .markets) {
//            <#Do me#>
//        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case nodes, markets
        
        enum ChildKeys: String, CodingKey {
            case id, name
        }
    }
}
//
let decoder = JSONDecoder()
decoder.userInfo[key] = nil

let decoded = try decoder.decode(Node.self, from: data)
for node in decoded.subnodes {
    print("\(node.identifier!):\t\(node.name!)")
}
