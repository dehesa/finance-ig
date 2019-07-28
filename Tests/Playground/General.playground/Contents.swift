import Foundation

let double = 9159795.995
let decimal = Decimal(floatLiteral: 9159795.995)

//
//struct JSONType: Decodable {
//    let amount: Double
//    let text: String
//
////    init(from decoder: Decoder) throws {
////        let container = try decoder.container(keyedBy: Self.CodingKeys.self)
////        let stringValue = try container.decode(Double.self, forKey: .amount)
////        self.amount = Decimal(string: "\(stringValue)")!
////        self.text = try container.decode(String.self, forKey: .text)
////    }
////
////    private enum CodingKeys: String, CodingKey {
////        case amount, text
////    }
//}
//
//let json = """
//{
//    "amount": 9159795.995,
//    "text": "9159795.995"
//}
//"""
//
//let decoder = JSONDecoder()
//let value = try! decoder.decode(JSONType.self, from: json.data(using: .utf8)!)
//value.amount
//String(value.amount)
//value.text
//
//Decimal(string: String(value.amount))
