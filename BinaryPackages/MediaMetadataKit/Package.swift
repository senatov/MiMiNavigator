// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "MediaMetadataKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "MediaMetadataKit", targets: ["MediaMetadataKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "MediaMetadataKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-088574402e51daba/MediaMetadataKit.xcframework.zip", checksum: "3d9d583676eee7a614e350d0875254562aa3fba650afa0f9593e17aaa6296332"),
        .target(name: "MediaMetadataKitDependencies", dependencies: ["MediaMetadataKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
