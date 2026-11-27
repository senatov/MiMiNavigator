// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "MediaMetadataKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "MediaMetadataKit", targets: ["MediaMetadataKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "MediaMetadataKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-620c6f4696b40b67/MediaMetadataKit.xcframework.zip", checksum: "db420eac25551b65a8450e5386e9f747e7923713b45d38cb6fd178544352a138"),
        .target(name: "MediaMetadataKitDependencies", dependencies: ["MediaMetadataKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
