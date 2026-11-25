// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ExternalToolsKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "ExternalToolsKit", targets: ["ExternalToolsKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "ExternalToolsKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-088574402e51daba/ExternalToolsKit.xcframework.zip", checksum: "d3d720456000e105a208d5353514c903deba449dc80fc939140e3483793bc1c8"),
        .target(name: "ExternalToolsKitDependencies", dependencies: ["ExternalToolsKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
