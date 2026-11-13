// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "NetworkKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "NetworkKit", targets: ["NetworkKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "NetworkKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-71ec12fc231c10ae/NetworkKit.xcframework.zip", checksum: "dbea16d02f23017bb724bd47ddd1abc9098411d22cebbc7f4f5b5b2ee2d6035d"),
        .target(name: "NetworkKitDependencies", dependencies: ["NetworkKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
