// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-package-registries",
    platforms: [
        .macOS(.v13), .iOS(.v16), .tvOS(.v16), .visionOS(.v1)
    ],
    products: [
        .library(name: "PackageRegistries", targets: ["PackageRegistries"]),
    ],
    targets: [
        .target(name: "PackageRegistries"),
        .testTarget(
            name: "PackageRegistriesTests",
            dependencies: ["PackageRegistries"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
