// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "LogKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "LogKit", targets: ["LogKitDependencies"])],
    dependencies: [.package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver", exact: "2.1.1")],
    targets: [
        .binaryTarget(name: "LogKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-71ec12fc231c10ae/LogKit.xcframework.zip", checksum: "37eafb86517fe946a10c8dc0d7c2e86a8ebd1333305d94c03561943ce487435c"),
        .target(name: "LogKitDependencies", dependencies: ["LogKit", .product(name: "SwiftyBeaver", package: "SwiftyBeaver")])
    ]
)
