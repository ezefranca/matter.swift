// swift-tools-version: 6.2

import PackageDescription

let testingPackage: Package.Dependency = .package(
    url: "https://github.com/swiftlang/swift-testing",
    revision: "swift-6.2.3-RELEASE"
)
let testingProduct: Target.Dependency = .product(
    name: "Testing",
    package: "swift-testing"
)

let package = Package(
    name: "p5.swift",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "P5",
            targets: ["P5"]
        ),
        .library(
            name: "Matter",
            targets: ["Matter"]
        ),
        .library(
            name: "ML5",
            targets: ["ML5"]
        ),
    ],
    dependencies: [testingPackage],
    targets: [
        .target(
            name: "P5"
        ),
        .testTarget(
            name: "P5Tests",
            dependencies: ["P5", testingProduct]
        ),
        .target(
            name: "Matter",
            resources: [
                .copy("Resources/Integration.metal")
            ]
        ),
        .testTarget(
            name: "MatterTests",
            dependencies: ["Matter", testingProduct]
        ),
        .target(
            name: "ML5"
        ),
        .testTarget(
            name: "ML5Tests",
            dependencies: ["ML5", testingProduct],
            resources: [
                .copy("Resources/BundledModel.mlmodel")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
