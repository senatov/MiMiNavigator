// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ArchiveKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "ArchiveKit", targets: ["ArchiveKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "ArchiveKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-3f53511a20cf81ff/ArchiveKit.xcframework.zip", checksum: "43529ffd4691c42e29904dd6e89861755135a121cda164cb221de853676960f1"),
        .target(name: "ArchiveKitDependencies", dependencies: ["ArchiveKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
