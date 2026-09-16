// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ArchiveKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "ArchiveKit", targets: ["ArchiveKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "ArchiveKit", path: "ArchiveKit.xcframework"),
        .target(name: "ArchiveKitDependencies", dependencies: ["ArchiveKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
