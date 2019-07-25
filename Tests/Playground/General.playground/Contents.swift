import Foundation

let formatter = NumberFormatter()
formatter.locale = .init(identifier: "en_US")
formatter.numberStyle = .decimal

let pl = "1,258.72"
formatter.number(from: pl)
