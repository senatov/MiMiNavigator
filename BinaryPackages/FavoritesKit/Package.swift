// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FavoritesKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "FavoritesKit", targets: ["FavoritesKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "FavoritesKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-ffba754c7dd76553/FavoritesKit.xcframework.zip", checksum: "36d6819f6b4d561bc0c0e80ee0f01b0cd65e0e325670eb0eca9a681aabcd25a1"),
        .target(name: "FavoritesKitDependencies", dependencies: ["FavoritesKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
