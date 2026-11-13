// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "FavoritesKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "FavoritesKit", targets: ["FavoritesKitDependencies"])],
    dependencies: [.package(path: "../LogKit"), .package(path: "../FileModelKit")],
    targets: [
        .binaryTarget(name: "FavoritesKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-71ec12fc231c10ae/FavoritesKit.xcframework.zip", checksum: "b72d108e7be42e152ca9bd4423efeb4d844310e0a1ec81af92204f55faf8cf57"),
        .target(name: "FavoritesKitDependencies", dependencies: ["FavoritesKit", .product(name: "LogKit", package: "LogKit"), .product(name: "FileModelKit", package: "FileModelKit")])
    ]
)
