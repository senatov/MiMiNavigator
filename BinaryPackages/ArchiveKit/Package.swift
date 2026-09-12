// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ArchiveKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "ArchiveKit", targets: ["ArchiveKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "ArchiveKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-ffba754c7dd76553/ArchiveKit.xcframework.zip", checksum: "0d2d1e83d4bd4268dd18d3d41248db7495ca516ff87491916fec95b2aaefecaa"),
        .target(name: "ArchiveKitDependencies", dependencies: ["ArchiveKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
