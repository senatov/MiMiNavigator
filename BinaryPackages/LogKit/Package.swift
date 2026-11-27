// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "LogKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "LogKit", targets: ["LogKitDependencies"])],
    dependencies: [.package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver", exact: "2.1.1")],
    targets: [
        .binaryTarget(name: "LogKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-620c6f4696b40b67/LogKit.xcframework.zip", checksum: "c5dd29ef21475a1fdc24b336cafc6e498ecdfc56305006da9386bac134fdd49e"),
        .target(name: "LogKitDependencies", dependencies: ["LogKit", .product(name: "SwiftyBeaver", package: "SwiftyBeaver")])
    ]
)
