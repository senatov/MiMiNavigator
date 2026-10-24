// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "MediaMetadataKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "MediaMetadataKit", targets: ["MediaMetadataKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "MediaMetadataKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-3f53511a20cf81ff/MediaMetadataKit.xcframework.zip", checksum: "390c51235b85770d4e46bec7f96cda2ab8c8c9693d74b0652e413829127e3a2e"),
        .target(name: "MediaMetadataKitDependencies", dependencies: ["MediaMetadataKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
