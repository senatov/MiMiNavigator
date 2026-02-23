// swift-tools-version: 6.0
// LogKit — shared logging module for MiMiNavigator and all its sub-packages.
// Wraps SwiftyBeaver; exposes a single global `log` constant.
// Usage in any package: import LogKit  →  log.debug("...")

import PackageDescription

let package = Package(
    name: "LogKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LogKit", type: .static, targets: ["LogKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver", from: "2.1.1"),
    ],
    targets: [
        .target(
            name: "LogKit",
            dependencies: [
                .product(name: "SwiftyBeaver", package: "SwiftyBeaver"),
            ],
            path: "Sources/LogKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
    ]
)
