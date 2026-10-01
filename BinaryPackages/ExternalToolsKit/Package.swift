// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ExternalToolsKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "ExternalToolsKit", targets: ["ExternalToolsKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "ExternalToolsKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-20351929fcfd1e2a/ExternalToolsKit.xcframework.zip", checksum: "0c47d8e6f7431e16a20706e382a4b18a512c1d90b8e36808e45bb819262b439c"),
        .target(name: "ExternalToolsKitDependencies", dependencies: ["ExternalToolsKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
