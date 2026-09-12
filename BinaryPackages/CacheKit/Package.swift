// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CacheKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "CacheKit", targets: ["CacheKitDependencies"])],
    dependencies: [.package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")],
    targets: [
        .binaryTarget(name: "CacheKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-ffba754c7dd76553/CacheKit.xcframework.zip", checksum: "275df729c9707b4778133c7b7f0a5995480280cea4dd085fcfb77c8e5fc57f0a"),
        .target(name: "CacheKitDependencies", dependencies: ["CacheKit", .product(name: "GRDB", package: "GRDB.swift")])
    ]
)
