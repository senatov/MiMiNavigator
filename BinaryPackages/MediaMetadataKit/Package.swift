// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MediaMetadataKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "MediaMetadataKit", targets: ["MediaMetadataKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "MediaMetadataKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-ffba754c7dd76553/MediaMetadataKit.xcframework.zip", checksum: "84d56d9d0330e6f6d4016019d5be2ffc39dea715068efcc57b55e0bee0c02a99"),
        .target(name: "MediaMetadataKitDependencies", dependencies: ["MediaMetadataKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
