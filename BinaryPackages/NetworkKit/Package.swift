// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NetworkKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "NetworkKit", targets: ["NetworkKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "NetworkKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-ffba754c7dd76553/NetworkKit.xcframework.zip", checksum: "0079524295c5c5aef8c530c73c66c54a622bd5b6e85b4df9fa671ee9dbca1f8c"),
        .target(name: "NetworkKitDependencies", dependencies: ["NetworkKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
