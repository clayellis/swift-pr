// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "swift-pr",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "SwiftPR", targets: ["SwiftPR"])
    ],
    dependencies: [
        .package(url: "https://github.com/clayellis/swift-arguments", branch: "main"),
        .package(url: "https://github.com/clayellis/swift-environment", branch: "main"),
        .package(url: "https://github.com/nerdishbynature/octokit.swift", branch: "main")
    ],
    targets: [
        .target(
            name: "SwiftPR",
            dependencies: [
                .product(name: "Arguments", package: "swift-arguments"),
                .product(name: "SwiftEnvironment", package: "swift-environment"),
                .product(name: "OctoKit", package: "octokit.swift")
            ]
        ),
        .testTarget(
            name: "SwiftPRTests",
            dependencies: ["SwiftPR"]
        ),
    ]
)
