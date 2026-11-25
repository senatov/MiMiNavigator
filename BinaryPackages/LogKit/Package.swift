// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "LogKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "LogKit", targets: ["LogKitDependencies"])],
    dependencies: [.package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver", exact: "2.1.1")],
    targets: [
        .binaryTarget(name: "LogKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-088574402e51daba/LogKit.xcframework.zip", checksum: "b79d95072d65ddb10bfe0d9f1667740a2ac1bb34119b909541abdf1d43c4d442"),
        .target(name: "LogKitDependencies", dependencies: ["LogKit", .product(name: "SwiftyBeaver", package: "SwiftyBeaver")])
    ]
)
