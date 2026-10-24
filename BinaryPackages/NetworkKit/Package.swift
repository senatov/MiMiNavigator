// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "NetworkKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "NetworkKit", targets: ["NetworkKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "NetworkKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-3f53511a20cf81ff/NetworkKit.xcframework.zip", checksum: "272b44185313bbc014683ee6bbbe0d8f58281c80d0c5c718ddfe2cdca4d0340a"),
        .target(name: "NetworkKitDependencies", dependencies: ["NetworkKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
