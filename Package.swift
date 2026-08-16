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
        .executable(name: "P5SmokeSample", targets: ["P5SmokeSample"]),
        .executable(name: "MatterSmokeSample", targets: ["MatterSmokeSample"]),
        .executable(name: "ML5SmokeSample", targets: ["ML5SmokeSample"]),
    ],
    dependencies: [testingPackage],
    targets: [
        .target(
            name: "P5",
            resources: [
                .copy("Resources/P5Renderer3D.metal"),
                .process("Resources/PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "P5Tests",
            dependencies: ["P5", testingProduct]
        ),
        .target(
            name: "Matter",
            resources: [
                .copy("Resources/Integration.metal"),
                .process("Resources/PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "MatterTests",
            dependencies: ["Matter", testingProduct]
        ),
        .target(
            name: "ML5",
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy")
            ]
        ),
        .testTarget(
            name: "ML5Tests",
            dependencies: ["ML5", testingProduct],
            resources: [
                .copy("Resources/BundledModel.model-fixture")
            ]
        ),
        .executableTarget(name: "P5SmokeSample", dependencies: ["P5"]),
        .executableTarget(name: "MatterSmokeSample", dependencies: ["Matter"]),
        .executableTarget(name: "ML5SmokeSample", dependencies: ["ML5"]),
    ],
    swiftLanguageModes: [.v6]
)
