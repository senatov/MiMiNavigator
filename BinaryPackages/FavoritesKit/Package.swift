// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "FavoritesKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "FavoritesKit", targets: ["FavoritesKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "FavoritesKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-620c6f4696b40b67/FavoritesKit.xcframework.zip", checksum: "959e1a4505ffac17eb6a271b9470363f0acd4752044877ebf239c6446d239d2b"),
        .target(name: "FavoritesKitDependencies", dependencies: ["FavoritesKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
