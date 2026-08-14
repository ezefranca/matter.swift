// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "P5Swift",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "P5Swift",
            targets: ["P5Swift"]
        ),
    ],
    targets: [
        .target(
            name: "P5Swift"
        ),
        .testTarget(
            name: "P5SwiftTests",
            dependencies: ["P5Swift"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
