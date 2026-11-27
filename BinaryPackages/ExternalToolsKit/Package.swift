// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ExternalToolsKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "ExternalToolsKit", targets: ["ExternalToolsKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "ExternalToolsKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-620c6f4696b40b67/ExternalToolsKit.xcframework.zip", checksum: "ae8a11216abf864229e9887b03f09f0e10bf1a372eca874f3a9fddf0f76d1a8f"),
        .target(name: "ExternalToolsKitDependencies", dependencies: ["ExternalToolsKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
