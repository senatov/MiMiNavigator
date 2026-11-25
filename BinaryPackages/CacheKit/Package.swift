// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "CacheKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "CacheKit", targets: ["CacheKitDependencies"])],
    dependencies: [.package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")],
    targets: [
        .binaryTarget(name: "CacheKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-088574402e51daba/CacheKit.xcframework.zip", checksum: "657d14f8c0f7c914c4308e83761ce121471a6cb6b5c2b259064295bd3b1005b1"),
        .target(name: "CacheKitDependencies", dependencies: ["CacheKit", .product(name: "GRDB", package: "GRDB.swift")])
    ]
)
