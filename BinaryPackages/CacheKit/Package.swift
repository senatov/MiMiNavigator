// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "CacheKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "CacheKit", targets: ["CacheKitDependencies"])],
    dependencies: [.package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")],
    targets: [
        .binaryTarget(name: "CacheKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-71ec12fc231c10ae/CacheKit.xcframework.zip", checksum: "7bb47fc432cbe01551726b6dfca3270dca38f89fd36ce245d0b2db644a976b20"),
        .target(name: "CacheKitDependencies", dependencies: ["CacheKit", .product(name: "GRDB", package: "GRDB.swift")])
    ]
)
