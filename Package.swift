// swift-tools-version:5.3
import PackageDescription

var package = Package(
    name: "IG",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13) //, .watchOS(.v6)
    ],
    products: [
        .library(name: "IG", targets: ["IG"])
    ],
    dependencies: [
        .package(url: "https://github.com/dehesa/Decimals.git", from: "0.1.0"),
        .package(url: "https://github.com/dehesa/Conbini.git", from: "0.6.2"),
    ],
    targets: [
        .binaryTarget(name: "Lightstreamer", url:"https://github.com/dehesa/IG/releases/download/0.11.2/Lightstreamer-2.1.3.zip", checksum: "5ca52be497d0a35cd05b3c5db0e9fc02be5d3c365ed048fa5b89432b3354256b"),
        .target(name: "IG", dependencies: ["Decimals", "Conbini", "Lightstreamer"], path: "sources"),
        .testTarget(name: "IGTests", dependencies: ["IG", .product(name: "ConbiniForTesting", package: "Conbini")], path: "tests"),
    ]
)
