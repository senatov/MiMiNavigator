// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ArchiveKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "ArchiveKit", targets: ["ArchiveKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "ArchiveKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-71ec12fc231c10ae/ArchiveKit.xcframework.zip", checksum: "edaa96860d0c02fdd6a7aa155c44083d1a1c110f73f7b7ce39f19c89716c5e5e"),
        .target(name: "ArchiveKitDependencies", dependencies: ["ArchiveKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
