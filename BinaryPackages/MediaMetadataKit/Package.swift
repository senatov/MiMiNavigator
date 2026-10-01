// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MediaMetadataKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "MediaMetadataKit", targets: ["MediaMetadataKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "MediaMetadataKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-20351929fcfd1e2a/MediaMetadataKit.xcframework.zip", checksum: "dffdf828246788416ea48809b9378a2cac2c732f168428a4f1c6f1399f99109a"),
        .target(name: "MediaMetadataKitDependencies", dependencies: ["MediaMetadataKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
