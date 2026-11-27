// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "CacheKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "CacheKit", targets: ["CacheKitDependencies"])],
    dependencies: [.package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")],
    targets: [
        .binaryTarget(name: "CacheKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-620c6f4696b40b67/CacheKit.xcframework.zip", checksum: "2151d822c953a5205328c3ca5a054077bfb451a4d691672682e3561b5d97e4cb"),
        .target(name: "CacheKitDependencies", dependencies: ["CacheKit", .product(name: "GRDB", package: "GRDB.swift")])
    ]
)
