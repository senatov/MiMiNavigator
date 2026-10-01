// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FavoritesKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "FavoritesKit", targets: ["FavoritesKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "FavoritesKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-20351929fcfd1e2a/FavoritesKit.xcframework.zip", checksum: "609f1cfa25d87a807daec5e34563836da70a0fb1294acb3dc91f2de36c5f52a0"),
        .target(name: "FavoritesKitDependencies", dependencies: ["FavoritesKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
