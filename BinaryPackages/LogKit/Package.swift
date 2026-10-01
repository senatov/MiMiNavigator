// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LogKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "LogKit", targets: ["LogKitDependencies"])],
    dependencies: [.package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver", exact: "2.1.1")],
    targets: [
        .binaryTarget(name: "LogKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-20351929fcfd1e2a/LogKit.xcframework.zip", checksum: "8f0cd2962d4d6aa5b68709505bff5dcf92b752e5c10ffb9c9068d1fcf3ca775e"),
        .target(name: "LogKitDependencies", dependencies: ["LogKit", .product(name: "SwiftyBeaver", package: "SwiftyBeaver")])
    ]
)
