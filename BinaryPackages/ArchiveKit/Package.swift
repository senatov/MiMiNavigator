// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ArchiveKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "ArchiveKit", targets: ["ArchiveKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "ArchiveKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-088574402e51daba/ArchiveKit.xcframework.zip", checksum: "6a1cd6e7bb09a7a8d46fe6005e8d7c0eca003d9bacf824363ce918e570b000a5"),
        .target(name: "ArchiveKitDependencies", dependencies: ["ArchiveKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
