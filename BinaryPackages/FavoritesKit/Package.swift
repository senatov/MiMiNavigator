// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "FavoritesKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "FavoritesKit", targets: ["FavoritesKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "FavoritesKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-088574402e51daba/FavoritesKit.xcframework.zip", checksum: "c84589e29284860e1240a7e70ed116b49ef11aa0d566b882bf60a5b97b5acdec"),
        .target(name: "FavoritesKitDependencies", dependencies: ["FavoritesKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
