// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "matter.swift",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Matter", targets: ["Matter"]),
        .executable(name: "MatterSmokeSample", targets: ["MatterSmokeSample"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-testing",
            revision: "swift-6.2.3-RELEASE"
        )
    ],
    targets: [
        .target(
            name: "Matter",
            resources: [
                .copy("Resources/Integration.metal"),
                .process("Resources/PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "MatterTests",
            dependencies: [
                "Matter",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .executableTarget(name: "MatterSmokeSample", dependencies: ["Matter"]),
    ],
    swiftLanguageModes: [.v6]
)
