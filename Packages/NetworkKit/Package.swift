// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NetworkKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "NetworkKit", type: .static, targets: ["NetworkKit"]),
    ],
    dependencies: [
        .package(path: "../LogKit"),
    ],
    targets: [
        .target(
            name: "NetworkKit",
            dependencies: [
                .product(name: "LogKit", package: "LogKit"),
            ],
            path: "Sources/NetworkKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "NetworkKitTests",
            dependencies: ["NetworkKit"]
        ),
    ]
)
