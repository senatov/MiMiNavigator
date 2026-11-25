// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "NetworkKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "NetworkKit", targets: ["NetworkKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "NetworkKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-088574402e51daba/NetworkKit.xcframework.zip", checksum: "720959aace9952c19e9ff3049b7902aa5c69fd999206c53463487d94bd26dc01"),
        .target(name: "NetworkKitDependencies", dependencies: ["NetworkKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
