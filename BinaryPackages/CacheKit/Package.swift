// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CacheKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "CacheKit", targets: ["CacheKitDependencies"])],
    dependencies: [.package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")],
    targets: [
        .binaryTarget(name: "CacheKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-20351929fcfd1e2a/CacheKit.xcframework.zip", checksum: "bba49969803ceacdb7340d419931698f836f9328d66fa641c1494b8d58fbd4ae"),
        .target(name: "CacheKitDependencies", dependencies: ["CacheKit", .product(name: "GRDB", package: "GRDB.swift")])
    ]
)
