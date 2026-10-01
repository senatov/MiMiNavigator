// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ArchiveKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "ArchiveKit", targets: ["ArchiveKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "ArchiveKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-20351929fcfd1e2a/ArchiveKit.xcframework.zip", checksum: "f440bfa8641856f795c6c17fa90d7192752e78edf69586868b42e16a33147d56"),
        .target(name: "ArchiveKitDependencies", dependencies: ["ArchiveKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
