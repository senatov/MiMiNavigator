// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "FileModelKit",
    platforms: [.macOS(.v27)],
    products: [.library(name: "FileModelKit", targets: ["FileModelKitDependencies"])],
    dependencies: [.package(path: "../LogKit")],
    targets: [
        .binaryTarget(name: "FileModelKit", url: "https://github.com/senatov/MiMiNavigator/releases/download/kits-71ec12fc231c10ae/FileModelKit.xcframework.zip", checksum: "486facf3245632d1fc3a5cc3997eebec06a9efdb61b1dd3da74cd96908413ce8"),
        .target(name: "FileModelKitDependencies", dependencies: ["FileModelKit", .product(name: "LogKit", package: "LogKit")])
    ]
)
