// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "SmartBotKitLWP",
    products: [
        .library(name: "SmartBotKitLWP", targets: ["SmartBotKitLWP"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SmartBotKitLWP",
            dependencies: [ ],
            path: "./src/"
            //, swiftSettings: [ .define("HEAVY_DEBUG") ]
        )
    ]
)
