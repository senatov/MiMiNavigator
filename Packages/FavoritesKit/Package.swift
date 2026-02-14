// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FavoritesKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "FavoritesKit",
            type: .static,
            targets: ["FavoritesKit"]
        ),
    ],
    targets: [
        .target(
            name: "FavoritesKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "FavoritesKitTests",
            dependencies: ["FavoritesKit"]
        ),
    ]
)
