// swift-tools-version:5.3
import PackageDescription

var package = Package(
    name: "IG",
    platforms: [
        .macOS(.v10_15) //, .iOS(.v13), .tvOS(.v13), .watchOS(.v6)
    ],
    products: [
        .library(name: "IG", targets: ["IG"])
    ],
    dependencies: [
        .package(url: "https://github.com/dehesa/Decimals.git", from: "0.1.0"),
        .package(url: "https://github.com/dehesa/Conbini.git", from: "0.6.1"),
    ],
    targets: [
        .binaryTarget(name: "Lightstreamer", url:"https://github.com/dehesa/IG/releases/download/0.11.0/Lightstreamer-2.1.2.zip", checksum: "fb40a5553b76bf87b447c84705f5630d1b860654a6af3cd0b4f2c8667a2b251c"),
        .target(name: "IG", dependencies: ["Decimals", "Conbini", "Lightstreamer"], path: "sources"),
        .testTarget(name: "IGTests", dependencies: ["IG", .product(name: "ConbiniForTesting", package: "Conbini")], path: "tests"),
    ]
)
