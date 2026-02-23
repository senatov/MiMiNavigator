// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FavoritesKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "FavoritesKit", type: .static, targets: ["FavoritesKit"]),
    ],
    dependencies: [
        .package(path: "../LogKit"),
    ],
    targets: [
        .target(
            name: "FavoritesKit",
            dependencies: [
                .product(name: "LogKit", package: "LogKit"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "FavoritesKitTests",
            dependencies: ["FavoritesKit"]
        ),
    ]
)
