import Combine
import Foundation

extension API.Request {
    /// List of endpoints related to navigation nodes.
    public struct Nodes {
        /// Pointer to the actual API instance in charge of calling the endpoints.
        fileprivate unowned let _api: API
        /// Hidden initializer passing the instance needed to perform the endpoint.
        /// - parameter api: The instance calling the actual endpoints.
        @usableFromInline internal init(api: API) { self._api = api }
    }
}

extension API.Request.Nodes {
    /// Returns the navigation node with the given id and all the children till a specified depth.
    /// - attention: For depths bigger than 0, several endpoints are hit (one for each node, it can easily be 100); thus, the callback may take a while. Be mindful of bigger depths.
    /// - parameter identifier: The identifier for the targeted node. If `nil`, the top-level nodes are returned.
    /// - parameter name: The name for the targeted name. If `nil`, the name of the node is not set on the returned `Node` instance.
    /// - parameter depth: The depth at which the tree will be travelled.  A negative integer will default to `0`.
    /// - returns: *Future* forwarding the node identified by the parameters recursively filled with the subnodes and submarkets till the given `depth`.
    public func get(identifier: String?, name: String? = nil, depth: Self.Depth = .none) -> AnyPublisher<API.Node,IG.Error> {
        let layers = depth._value
        guard layers > 0 else {
            return Self._get(api: self._api, node: .init(identifier: identifier, name: name))
        }
        
        return Self._iterate(api: self._api, node: .init(identifier: identifier, name: name), depth: layers)
    }

    // MARK: GET /markets/{searchTerm}
    
    /// Returns all markets matching the search term.
    ///
    /// The search term cannot be an empty string.
    /// - parameter searchTerm: The term to be used in the search. This parameter is mandatory and cannot be empty.
    /// - returns: *Future* forwarding all markets matching the search term.
    public func getMarkets(matching searchTerm: String) -> AnyPublisher<[API.Node.Market],IG.Error> {
        self._api.publisher { (api) -> String in
                guard !searchTerm.isEmpty else {
                    throw IG.Error(.api(.invalidRequest), "Search for markets failed! The search term cannot be empty.", help: "Read the request documentation and be sure to follow all requirements.")
                }
                return searchTerm
            }.makeRequest(.get, "markets", version: 1, credentials: true, queries: { [.init(name: "searchTerm", value: $0)] })
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .default(date: true)) { (w: _WrapperSearch, _) in w.markets }
            .mapError(errorCast)
            .eraseToAnyPublisher()
    }

    // MARK: GET /marketnavigation/{nodeId}
    
    /// Returns all data of the given navigation node.
    ///
    /// The subnodes are not recursively retrieved; thus only a flat hierarchy will be built with this endpoint..
    /// - parameter node: The entity targeting a specific node. Only the identifier is used.
    /// - returns: *Future* forwarding a *full* node.
    private static func _get(api: API, node: API.Node) -> AnyPublisher<API.Node,IG.Error> {
        api.publisher
            .makeRequest(.get, "marketnavigation/\(node.identifier ?? "")", version: 1, credentials: true)
            .send(expecting: .json, statusCode: 200)
            .decodeJSON(decoder: .custom({ (request, response, _) -> JSONDecoder in
                guard let dateString = response.allHeaderFields[API.HTTP.Header.Key.date.rawValue] as? String,
                      let date = DateFormatter.humanReadableLong.date(from: dateString) else {
                        throw IG.Error(.api(.invalidResponse), "The response date couldn't be extracted from the response header.", help: "A unexpected error was encountered. Please contact the repository maintainer and attach this debug print.", info: ["Request": request, "Response": response])
                }
                
                return JSONDecoder().set {
                    $0.userInfo[API.JSON.DecoderKey.responseDate] = date
                    
                    if let identifier = node.identifier {
                        $0.userInfo[API.JSON.DecoderKey._nodeIdentifier] = identifier
                    }
                    if let name = node.name {
                        $0.userInfo[API.JSON.DecoderKey._nodeName] = name
                    }
                }
            })).mapError(errorCast)
            .eraseToAnyPublisher()
    }
    
    /// Returns the navigation node indicated by the given node argument as well as all its children till a given depth.
    /// - parameter node: The entity targeting a specific node. Only the identifier is used for identification purposes.
    /// - parameter depth: The depth at which the tree will be travelled.  A negative integer will default to `0`.
    /// - returns: *Future* forwarding the node given as an argument with complete subnodes and submarkets information.
    private static func _iterate(api: API, node: API.Node, depth: Int) -> AnyPublisher<API.Node,IG.Error> {
        // 1. Retrieve the targeted node.
        return _get(api: api, node: node).flatMap { [weak weakAPI = api] (node) -> AnyPublisher<API.Node,IG.Error> in
            let countdown = depth - 1
            // 2. If there aren't any more levels to drill down into or the target node doesn't have subnodes, send the targeted node.
            guard countdown >= 0, let subnodes = node.subnodes, !subnodes.isEmpty else {
                return Result.Publisher(node).eraseToAnyPublisher()
            }
            // 3. Check the API instance is still there.
            guard let api = weakAPI else {
                return Fail<API.Node,IG.Error>(error: IG.Error(.api(.sessionExpired), "The API instance has been deallocated.", help: "The API functionality is asynchronous. Keep around the API instance while the request/response is being processed."))
                    .eraseToAnyPublisher()
            }
            
            /// The result of this combine pipeline.
            let subject = PassthroughSubject<API.Node,IG.Error>()
            /// The root node from which to look for subnodes.
            var parent = node
            /// This closure retrieves the child node at the `parent` index `childIndex` and calls itself recursively until there are no more children in `parent.subnodes`.
            var fetchChildren: ((_ api: API, _ childIndex: Int, _ childDepth: Int) -> AnyCancellable?)! = nil
            /// `Cancellable` to stop fetching the `parent.subnodes`.
            var childrenFetchingCancellable: AnyCancellable? = nil
            
            fetchChildren = { (childAPI, childIndex, childDepth) in
                // 5. Retrieve the child node indicated by the index.
                _iterate(api: childAPI, node: parent.subnodes![childIndex], depth: childDepth)
                    .sink(receiveCompletion: {
                        if case .failure(let error) = $0 {
                            subject.send(completion: .failure(error))
                            childrenFetchingCancellable = nil
                            return
                        }
                        // 6. Check if there is a "next" sibling.
                        let nextChildIndex = childIndex + 1
                        // 7. If there aren't any more siblings, forward the parent downstream since we have retrieved all the information.
                        guard nextChildIndex < parent.subnodes!.count else {
                            subject.send(parent)
                            subject.send(completion: .finished)
                            childrenFetchingCancellable = nil
                            return
                        }
                        // 8. If the API instance has been deallocated, forward an error downstream.
                        guard let api = weakAPI else {
                            subject.send(completion: .failure(IG.Error(.api(.sessionExpired), "The API instance has been deallocated.", help: "The API functionality is asynchronous. Keep around the API instance while the request/response is being processed.")))
                            childrenFetchingCancellable?.cancel()
                            return
                        }
                        // 9. If there are more siblings, keep iterating.
                        childrenFetchingCancellable = fetchChildren(api, nextChildIndex, childDepth)
                    }, receiveValue: { parent.subnodes![childIndex] = $0 })
            }
            
            // 4. Retrieve children nodes, starting by the first one.
            defer { childrenFetchingCancellable = fetchChildren(api, 0, countdown) }
            return subject.eraseToAnyPublisher()
        }.eraseToAnyPublisher()
    }
}

// MARK: - Entities

extension API.Request.Nodes {
    /// Express the depth of a computed tree.
    public enum Depth: ExpressibleByNilLiteral, ExpressibleByIntegerLiteral {
        /// No depth (outside the targeted node).
        case none
        /// Number of subnodes layers under the targeted node will be queried.
        case layers(UInt)
        /// All nodes under the targeted node will be queried.
        case all
        
        public init(nilLiteral: ()) {
            self = .none
        }
        
        public init(integerLiteral value: UInt) {
            if value == 0 {
                self = .none
            } else {
                self = .layers(value)
            }
        }
        
        fileprivate var _value: Int {
            switch self {
            case .none:
                return 0
            case .layers(let value):
                return Int(clamping: value)
            case .all:
                return Int.max
            }
        }
    }
}

extension API.Request.Nodes {
    private struct _WrapperSearch: Decodable {
        let markets: [API.Node.Market]
    }
}

extension API {
    /// Node within the Broker platform markets organization.
    public struct Node: Decodable {
        /// Node identifier.
        /// - note: The top of the tree will return `nil` for this property.
        public let identifier: String?
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
        
        fileprivate init(identifier: String?, name: String?) {
            self.identifier = identifier
            self.name = name
            self.subnodes = nil
            self.markets = nil
        }
        
        public init(from decoder: Decoder) throws {
            self.identifier = decoder.userInfo[API.JSON.DecoderKey._nodeIdentifier] as? String
            self.name = decoder.userInfo[API.JSON.DecoderKey._nodeName] as? String
            
            let container = try decoder.container(keyedBy: _CodingKeys.self)
            
            var subnodes: [API.Node] = []
            if container.contains(.nodes), try !container.decodeNil(forKey: .nodes) {
                var array = try container.nestedUnkeyedContainer(forKey: .nodes)
                while !array.isAtEnd {
                    let nodeContainer = try array.nestedContainer(keyedBy: _CodingKeys._ChildKeys.self)
                    let id = try nodeContainer.decode(String.self, forKey: .id)
                    let name = try nodeContainer.decode(String.self, forKey: .name)
                    subnodes.append(.init(identifier: id, name: name))
                }
            }
            self.subnodes = subnodes
            
            if container.contains(.markets), try !container.decodeNil(forKey: .markets) {
                self.markets = try container.decode(Array<Self.Market>.self, forKey: .markets)
            } else {
                self.markets = []
            }
        }
        
        private enum _CodingKeys: String, CodingKey {
            case nodes, markets
            
            enum _ChildKeys: String, CodingKey {
                case id, name
            }
        }
    }
}

// MARK: - Functionality

fileprivate extension API.JSON.DecoderKey {
    /// Key for JSON decoders under which a node identifier will be stored.
    static let _nodeIdentifier = CodingUserInfoKey(rawValue: "IG_APINodeId")!
    /// Key for JSON decoders under which a node name will be stored.
    static let _nodeName = CodingUserInfoKey(rawValue: "IG_APINodeName")!
}
