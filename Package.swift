// swift-tools-version: 6.2

import PackageDescription

let usesSwiftTestingPackage =
    Context.environment["P5_USE_SWIFT_TESTING_PACKAGE"] == "1"

var packageDependencies: [Package.Dependency] = []
var testDependencies: [Target.Dependency] = ["P5"]
var matterTestDependencies: [Target.Dependency] = ["Matter"]
var ml5TestDependencies: [Target.Dependency] = ["ML5"]

if usesSwiftTestingPackage {
    packageDependencies.append(
        .package(
            url: "https://github.com/swiftlang/swift-testing",
            revision: "swift-6.2.3-RELEASE"
        )
    )
    let testingProduct: Target.Dependency = .product(
        name: "Testing",
        package: "swift-testing"
    )
    testDependencies.append(testingProduct)
    matterTestDependencies.append(testingProduct)
    ml5TestDependencies.append(testingProduct)
}

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
    dependencies: packageDependencies,
    targets: [
        .target(
            name: "P5"
        ),
        .testTarget(
            name: "P5Tests",
            dependencies: testDependencies
        ),
        .target(
            name: "Matter",
            resources: [
                .copy("Resources/Integration.metal"),
            ]
        ),
        .testTarget(
            name: "MatterTests",
            dependencies: matterTestDependencies
        ),
        .target(
            name: "ML5"
        ),
        .testTarget(
            name: "ML5Tests",
            dependencies: ml5TestDependencies
        ),
    ],
    swiftLanguageModes: [.v6]
)
