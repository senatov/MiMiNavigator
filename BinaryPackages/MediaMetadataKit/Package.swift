// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "MediaMetadataKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "MediaMetadataKit", targets: ["MediaMetadataKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "MediaMetadataKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-71ec12fc231c10ae/MediaMetadataKit.xcframework.zip", checksum: "8b64948adbfe3e78bd386ce624ea95f3f180316ff467203a4819271a51bb5bd2"),
        .target(name: "MediaMetadataKitDependencies", dependencies: ["MediaMetadataKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
