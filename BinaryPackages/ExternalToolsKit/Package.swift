// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ExternalToolsKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "ExternalToolsKit", targets: ["ExternalToolsKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "ExternalToolsKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-71ec12fc231c10ae/ExternalToolsKit.xcframework.zip", checksum: "b877b06fb8a0e6f01cd6ddb1d3d5437aba919d8cc4220aeabd43b661ecbc58f7"),
        .target(name: "ExternalToolsKitDependencies", dependencies: ["ExternalToolsKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
