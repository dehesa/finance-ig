import Decimals

extension Decimal64: Codable {
    // TODO: Figure out how to access the JSON low-level bits directly.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let number = try container.decode(Double.self)
        self = try Decimal64(number) ?> DecodingError.dataCorruptedError(in: container, debugDescription: "The Double '\(number)' couldn't be transformed into a Decimal64 number")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Double(self.description)!)
    }
}
