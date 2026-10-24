// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "FavoritesKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "FavoritesKit", targets: ["FavoritesKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "FavoritesKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-3f53511a20cf81ff/FavoritesKit.xcframework.zip", checksum: "3c4bbc46eee4d145d8735efa4f395d1c50d85ce5fcf21ad93f6027b3a028cf36"),
        .target(name: "FavoritesKitDependencies", dependencies: ["FavoritesKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
