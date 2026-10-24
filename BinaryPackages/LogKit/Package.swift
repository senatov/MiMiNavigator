// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "LogKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "LogKit", targets: ["LogKitDependencies"])],
    dependencies: [.package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver", exact: "2.1.1")],
    targets: [
        .binaryTarget(name: "LogKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-3f53511a20cf81ff/LogKit.xcframework.zip", checksum: "ef1b69602dac1c007ed50a6c32b0fda821656bf918b59783a14f6e816df3f9a5"),
        .target(name: "LogKitDependencies", dependencies: ["LogKit", .product(name: "SwiftyBeaver", package: "SwiftyBeaver")])
    ]
)
