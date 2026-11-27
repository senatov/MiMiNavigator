// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "NetworkKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "NetworkKit", targets: ["NetworkKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "NetworkKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-620c6f4696b40b67/NetworkKit.xcframework.zip", checksum: "280428f341d7cc6267adf9f75f6a32234b8d5b74265da281d4ca4ebbe3da48ff"),
        .target(name: "NetworkKitDependencies", dependencies: ["NetworkKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
