// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CacheKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "CacheKit", targets: ["CacheKitDependencies"])],
    dependencies: [.package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")],
    targets: [
        .binaryTarget(name: "CacheKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-3f53511a20cf81ff/CacheKit.xcframework.zip", checksum: "d3bcd0264ec15ed4bdbe0dc7ab803cae80983ca9158c9506c8f274afc5e768e4"),
        .target(name: "CacheKitDependencies", dependencies: ["CacheKit", .product(name: "GRDB", package: "GRDB.swift")])
    ]
)
