// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NetworkKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "NetworkKit", targets: ["NetworkKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "NetworkKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-20351929fcfd1e2a/NetworkKit.xcframework.zip", checksum: "1dbef59a3de261d1770185750f123c975d8b8bf9fe0f2a9c709de14792b1112a"),
        .target(name: "NetworkKitDependencies", dependencies: ["NetworkKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
