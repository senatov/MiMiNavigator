// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ExternalToolsKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "ExternalToolsKit", targets: ["ExternalToolsKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "ExternalToolsKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-ffba754c7dd76553/ExternalToolsKit.xcframework.zip", checksum: "bb9437008e7836350c5ae20cd3b17d22e30a00b80fff913bebf2d90ae34c4dbd"),
        .target(name: "ExternalToolsKitDependencies", dependencies: ["ExternalToolsKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
