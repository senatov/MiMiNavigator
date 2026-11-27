// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ArchiveKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "ArchiveKit", targets: ["ArchiveKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "ArchiveKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-620c6f4696b40b67/ArchiveKit.xcframework.zip", checksum: "d20a9b25f24c74bff8c9d7615c735c8ab3740f44fe27be70ff04d41274a6228c"),
        .target(name: "ArchiveKitDependencies", dependencies: ["ArchiveKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
