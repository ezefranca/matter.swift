// swift-tools-version: 6.2

import PackageDescription

let usesSwiftTestingPackage =
    Context.environment["P5_USE_SWIFT_TESTING_PACKAGE"] == "1"

var packageDependencies: [Package.Dependency] = []
var testDependencies: [Target.Dependency] = ["P5"]

if usesSwiftTestingPackage {
    packageDependencies.append(
        .package(
            url: "https://github.com/swiftlang/swift-testing",
            revision: "swift-6.2.3-RELEASE"
        )
    )
    testDependencies.append(
        .product(name: "Testing", package: "swift-testing")
    )
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
    ],
    swiftLanguageModes: [.v6]
)
